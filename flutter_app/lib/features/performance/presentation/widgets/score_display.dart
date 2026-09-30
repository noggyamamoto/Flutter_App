import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../score/domain/entities/musical_score.dart';

// Exibe um trecho curto da partitura (RFA04 / RU08), com símbolos ampliados,
// cores de feedback por nota (RFA06) e cursor de posição.
class ScoreDisplay extends StatelessWidget {
  // Partitura completa.
  final MusicalScore score;

  // Compassos exibidos (normalmente os da frase atual).
  final List<int> measureIndexes;

  // Cor de cada nota avaliada (verde/laranja/vermelho).
  final Map<int, Color> noteColors;

  // Notas que fazem parte do gabarito (as demais aparecem em cinza).
  final Set<int>? evaluatedNoteIds;

  // Posição atual da execução (semínimas) ou null.
  final double? cursorBeat;

  // Ampliação dos símbolos (1.0 = normal).
  final double zoom;

  const ScoreDisplay({
    super.key,
    required this.score,
    required this.measureIndexes,
    this.noteColors = const {},
    this.evaluatedNoteIds,
    this.cursorBeat,
    this.zoom = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    if (score.measures.isEmpty || measureIndexes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma nota encontrada.',
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final layout = ScoreLayout.compute(
          score: score,
          measureIndexes: measureIndexes,
          width: width,
          zoom: zoom,
        );

        return SingleChildScrollView(
          child: SizedBox(
            width: width,
            height: layout.height,
            child: CustomPaint(
              painter: _ScorePainter(
                score: score,
                layout: layout,
                noteColors: noteColors,
                evaluatedNoteIds: evaluatedNoteIds,
                cursorBeat: cursorBeat,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==========================================================================
// LAYOUT
// ==========================================================================

// Posição horizontal de um compasso dentro de uma linha (sistema).
class MeasureLayout {
  final int measureIndex;
  final double x;
  final double width;

  // Início do conteúdo (após clave/armadura/fórmula).
  final double contentX;

  // Instante (semínimas) -> posição x de cada ataque.
  final Map<double, double> onsetX;

  // Cabeçalho desenhado no início do compasso.
  final bool drawClef;
  final bool drawKey;
  final bool drawTime;

  const MeasureLayout({
    required this.measureIndex,
    required this.x,
    required this.width,
    required this.contentX,
    required this.onsetX,
    required this.drawClef,
    required this.drawKey,
    required this.drawTime,
  });

  double get endX => x + width;

  // Converte um instante em posição x (interpolação entre ataques).
  double xForBeat(double beat, double measureStart, double measureEnd) {
    final entries = onsetX.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return contentX;
    if (beat <= entries.first.key) return entries.first.value;
    for (var i = 0; i < entries.length - 1; i++) {
      final a = entries[i];
      final b = entries[i + 1];
      if (beat >= a.key && beat <= b.key) {
        final t = (beat - a.key) / (b.key - a.key);
        return a.value + (b.value - a.value) * t;
      }
    }
    final last = entries.last;
    final t = ((beat - last.key) / math.max(1e-6, measureEnd - last.key)).clamp(0.0, 1.0);
    return last.value + (endX - last.value) * t;
  }
}

class SystemLayout {
  final double top;
  final List<MeasureLayout> measures;

  const SystemLayout({required this.top, required this.measures});
}

class ScoreLayout {
  // Espaço entre linhas da pauta.
  final double space;
  final int staves;
  final List<SystemLayout> systems;
  final double height;

  const ScoreLayout({
    required this.space,
    required this.staves,
    required this.systems,
    required this.height,
  });

  // Distâncias verticais (em espaços de pauta).
  static const double topPadding = 5;
  static const double staffGap = 7;
  static const double bottomPadding = 5;

  double staffTop(SystemLayout system, int staff) {
    final first = system.top + topPadding * space;
    return staff <= 1 ? first : first + (4 + staffGap) * space;
  }

  double staffBottom(SystemLayout system, int staff) => staffTop(system, staff) + 4 * space;

  double systemHeight() =>
      (topPadding + 4 + (staves > 1 ? staffGap + 4 : 0) + bottomPadding) * space;

  static ScoreLayout compute({
    required MusicalScore score,
    required List<int> measureIndexes,
    required double width,
    required double zoom,
  }) {
    final space = (width / 62).clamp(7.0, 12.0) * zoom;
    final staves = score.staves.clamp(1, 2);

    // Quantidade de compassos por linha conforme a largura da tela.
    final perLine = math.max(1, (width / (space * 17)).floor()).clamp(1, 4);

    final systems = <SystemLayout>[];
    final systemHeight =
        (topPadding + 4 + (staves > 1 ? staffGap + 4 : 0) + bottomPadding) * space;

    for (var start = 0; start < measureIndexes.length; start += perLine) {
      final line = measureIndexes.sublist(start, math.min(start + perLine, measureIndexes.length));
      final top = systems.length * systemHeight;
      systems.add(
        SystemLayout(
          top: top,
          measures: _layoutLine(
            score: score,
            line: line,
            width: width,
            space: space,
            firstLineOfFragment: start == 0,
          ),
        ),
      );
    }

    return ScoreLayout(
      space: space,
      staves: staves,
      systems: systems,
      height: systems.length * systemHeight,
    );
  }

  static List<MeasureLayout> _layoutLine({
    required MusicalScore score,
    required List<int> line,
    required double width,
    required double space,
    required bool firstLineOfFragment,
  }) {
    final left = space * 1.5;
    final right = width - space;

    // Pesos de espaçamento de cada ataque (figuras longas ocupam mais espaço).
    final weights = <int, List<MapEntry<double, double>>>{};
    final measureWeight = <int, double>{};

    for (final index in line) {
      final measure = score.measures[index];
      final onsets = measure.notes.map((n) => _key(n.startBeat)).toSet().toList()..sort();
      if (onsets.isEmpty) onsets.add(_key(measure.startBeat));

      final list = <MapEntry<double, double>>[];
      for (var i = 0; i < onsets.length; i++) {
        final next = i + 1 < onsets.length ? onsets[i + 1] : measure.endBeat;
        final gap = math.max(0.125, next - onsets[i]);
        final w = 1.4 + 0.9 * (math.log(1 + gap / 0.25) / math.ln2);
        list.add(MapEntry(onsets[i], w));
      }
      weights[index] = list;
      measureWeight[index] = math.max(3.0, list.fold(0.0, (s, e) => s + e.value));
    }

    // Cabeçalho da linha: clave + armadura (+ fórmula na primeira linha).
    final firstMeasure = score.measures[line.first];
    final keyWidth = firstMeasure.fifths.abs() * space * 1.1 + (firstMeasure.fifths != 0 ? space : 0);
    final drawTimeFirst = firstLineOfFragment || firstMeasure.showTime;
    final header = space * 4 + keyWidth + (drawTimeFirst ? space * 3 : 0);

    // Mudanças de fórmula/armadura no meio da linha.
    double extraHeader(int index, bool first) {
      if (first) return 0;
      final m = score.measures[index];
      var extra = 0.0;
      if (m.showKey) extra += m.fifths.abs() * space * 1.1 + space;
      if (m.showTime) extra += space * 3;
      return extra;
    }

    final totalWeight = line.fold(0.0, (s, i) => s + measureWeight[i]!);
    final extras = line.asMap().entries.fold(0.0, (s, e) => s + extraHeader(e.value, e.key == 0));
    final available = right - left - header - extras;

    final result = <MeasureLayout>[];
    var x = left;

    for (var i = 0; i < line.length; i++) {
      final index = line[i];
      final first = i == 0;
      final ownHeader = first ? header : extraHeader(index, false);
      final contentWidth = available * measureWeight[index]! / totalWeight;
      final measureWidth = ownHeader + contentWidth;
      final contentX = x + ownHeader + space * 1.6;
      final usable = contentWidth - space * 2.4;

      final onsetX = <double, double>{};
      final list = weights[index]!;
      final sum = list.fold(0.0, (s, e) => s + e.value);
      var acc = 0.0;
      for (final entry in list) {
        onsetX[entry.key] = contentX + usable * acc / sum;
        acc += entry.value;
      }

      final m = score.measures[index];
      result.add(
        MeasureLayout(
          measureIndex: index,
          x: x,
          width: measureWidth,
          contentX: contentX,
          onsetX: onsetX,
          drawClef: first,
          drawKey: first || m.showKey,
          drawTime: first ? drawTimeFirst : m.showTime,
        ),
      );
      x += measureWidth;
    }

    return result;
  }

  static double _key(double beat) => (beat * 1000).roundToDouble() / 1000;
}

// ==========================================================================
// DESENHO
// ==========================================================================

class _ScorePainter extends CustomPainter {
  final MusicalScore score;
  final ScoreLayout layout;
  final Map<int, Color> noteColors;
  final Set<int>? evaluatedNoteIds;
  final double? cursorBeat;

  _ScorePainter({
    required this.score,
    required this.layout,
    required this.noteColors,
    required this.evaluatedNoteIds,
    required this.cursorBeat,
  });

  double get s => layout.space;

  static const Color _ink = Colors.black;
  static const Color _accompaniment = Color(0xFF8A8894);

  @override
  void paint(Canvas canvas, Size size) {
    for (final system in layout.systems) {
      _paintCursor(canvas, system);
      _paintStaves(canvas, system);
      for (final measure in system.measures) {
        _paintMeasureHeader(canvas, system, measure);
        _paintMeasureNotes(canvas, system, measure);
        _paintBarline(canvas, system, measure);
      }
      _paintTies(canvas, system);
    }
  }

  // ------------------------------------------------------------------------
  // Pautas, barras e cabeçalhos
  // ------------------------------------------------------------------------

  void _paintStaves(Canvas canvas, SystemLayout system) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = math.max(1, s * 0.1);
    final startX = system.measures.first.x;
    final endX = system.measures.last.endX;

    for (var staff = 1; staff <= layout.staves; staff++) {
      final top = layout.staffTop(system, staff);
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(Offset(startX, top + i * s), Offset(endX, top + i * s), paint);
      }
    }

    // Barra inicial ligando as pautas e chave do piano.
    final top = layout.staffTop(system, 1);
    final bottom = layout.staffBottom(system, layout.staves);
    canvas.drawLine(Offset(startX, top), Offset(startX, bottom), paint);
    if (layout.staves > 1) {
      _paintBrace(canvas, startX - s * 0.5, top, bottom);
    }

    // Número do primeiro compasso da linha.
    final number = score.measures[system.measures.first.measureIndex].number;
    _text(canvas, number, Offset(startX, top - s * 2.6), s * 1.2, color: Colors.black54);
  }

  void _paintBrace(Canvas canvas, double x, double top, double bottom) {
    final mid = (top + bottom) / 2;
    final w = s * 0.9;
    final path = Path()
      ..moveTo(x, top)
      ..cubicTo(x - w, top + (mid - top) * 0.3, x, mid - s, x - w, mid)
      ..cubicTo(x, mid + s, x - w, bottom - (bottom - mid) * 0.3, x, bottom);
    canvas.drawPath(
      path,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22,
    );
  }

  void _paintBarline(Canvas canvas, SystemLayout system, MeasureLayout measure) {
    final top = layout.staffTop(system, 1);
    final bottom = layout.staffBottom(system, layout.staves);
    final isLast = measure.measureIndex == score.measures.length - 1;
    final thin = Paint()
      ..color = _ink
      ..strokeWidth = math.max(1, s * 0.12);

    if (isLast) {
      // Barra final: fina + grossa.
      canvas.drawLine(Offset(measure.endX - s * 0.8, top), Offset(measure.endX - s * 0.8, bottom), thin);
      canvas.drawRect(Rect.fromLTRB(measure.endX - s * 0.45, top, measure.endX, bottom), Paint()..color = _ink);
    } else {
      canvas.drawLine(Offset(measure.endX, top), Offset(measure.endX, bottom), thin);
    }
  }

  void _paintMeasureHeader(Canvas canvas, SystemLayout system, MeasureLayout layoutM) {
    final measure = score.measures[layoutM.measureIndex];
    var x = layoutM.x + s * 0.6;

    for (var staff = 1; staff <= layout.staves; staff++) {
      var hx = x;
      final clef = measure.clefs[staff] ?? (staff == 1 ? 'G' : 'F');
      final top = layout.staffTop(system, staff);

      if (layoutM.drawClef) {
        _paintClef(canvas, clef, hx, top);
        hx += s * 3.6;
      }

      if (layoutM.drawKey && measure.fifths != 0) {
        _paintKeySignature(canvas, measure.fifths, clef, hx, top);
        hx += measure.fifths.abs() * s * 1.1 + s;
      }

      if (layoutM.drawTime) {
        final size = s * 2.3;
        _text(canvas, '${measure.beats}', Offset(hx + s * 0.2, top - s * 0.25), size, bold: true);
        _text(canvas, '${measure.beatType}', Offset(hx + s * 0.2, top + s * 1.75), size, bold: true);
      }
    }
  }

  void _paintClef(Canvas canvas, String clef, double x, double top) {
    if (clef == 'F') {
      // Clave de fá: centro na 4ª linha (de baixo para cima).
      _text(canvas, '𝄢', Offset(x, top - s * 1.35), s * 4.1, music: true);
    } else if (clef == 'C') {
      _text(canvas, '𝄡', Offset(x, top - s * 0.9), s * 4.2, music: true);
    } else {
      // Clave de sol: espiral na 2ª linha.
      _text(canvas, '𝄞', Offset(x - s * 0.1, top - s * 2.55), s * 6.3, music: true);
    }
  }

  // Posições (diatônicas) dos acidentes da armadura na clave de sol.
  static const _sharpOrder = [38, 35, 39, 36, 33, 37, 34]; // F5 C5 G5 D5 A4 E5 B4
  static const _flatOrder = [34, 37, 33, 36, 32, 35, 31]; // B4 E5 A4 D5 G4 C5 F4

  void _paintKeySignature(Canvas canvas, int fifths, String clef, double x, double top) {
    final positions = fifths > 0 ? _sharpOrder : _flatOrder;
    final symbol = fifths > 0 ? '♯' : '♭';
    final shift = clef == 'F' ? -14 : (clef == 'C' ? -7 : 0);
    for (var i = 0; i < fifths.abs() && i < 7; i++) {
      final diatonic = positions[i] + shift;
      final y = _yForDiatonic(top, clef, diatonic);
      _text(canvas, symbol, Offset(x + i * s * 1.1, y - s * 1.55), s * 2.4, music: true);
    }
  }

  // ------------------------------------------------------------------------
  // Notas
  // ------------------------------------------------------------------------

  int _bottomLine(String clef) => clef == 'F' ? 18 : (clef == 'C' ? 24 : 30);

  double _yForDiatonic(double staffTop, String clef, int diatonic) {
    final bottom = staffTop + 4 * s;
    return bottom - (diatonic - _bottomLine(clef)) * s / 2;
  }

  Color _colorFor(ScoreNote note) {
    final color = noteColors[note.id];
    if (color != null) return color;
    if (evaluatedNoteIds != null && !evaluatedNoteIds!.contains(note.id)) {
      return _accompaniment;
    }
    return _ink;
  }

  void _paintMeasureNotes(Canvas canvas, SystemLayout system, MeasureLayout ml) {
    final measure = score.measures[ml.measureIndex];

    // Agrupa acordes: nota principal + membros com o mesmo início/pauta/voz.
    final chords = <List<ScoreNote>>[];
    for (final note in measure.notes) {
      if (note.isChordMember && chords.isNotEmpty) {
        chords.last.add(note);
      } else {
        chords.add([note]);
      }
    }

    // Informações de haste por acorde, usadas pelas barras de colcheia.
    final stems = <_StemInfo>[];

    for (final chord in chords) {
      final main = chord.first;
      if (main.staff > layout.staves) continue;
      final clef = measure.clefs[main.staff] ?? (main.staff == 1 ? 'G' : 'F');
      final top = layout.staffTop(system, main.staff);
      final x = ml.onsetX[ScoreLayout._key(main.startBeat)] ?? ml.contentX;

      if (main.isRest) {
        final isWholeMeasure = main.durationBeats >= measure.durationBeats - 1e-6;
        final rx = isWholeMeasure ? (ml.contentX + ml.endX) / 2 - s : x;
        _paintRest(canvas, main, rx, top, _colorFor(main));
        continue;
      }

      final stem = _paintChord(canvas, chord, clef, x, top);
      if (stem != null) stems.add(stem);
    }

    _paintBeams(canvas, stems);
  }

  _StemInfo? _paintChord(
    Canvas canvas,
    List<ScoreNote> chord,
    String clef,
    double x,
    double top,
  ) {
    final notes = [...chord]..sort((a, b) => a.diatonic.compareTo(b.diatonic));
    final main = chord.first;
    final headW = s * 1.18;
    final headH = s * 0.92;
    final middle = _bottomLine(clef) + 4;

    // Direção da haste: do arquivo ou pela posição média.
    final avg = notes.fold(0, (sum, n) => sum + n.diatonic) / notes.length;
    final up = main.stem == 'up' ? true : (main.stem == 'down' ? false : avg < middle);

    final hollow = main.type == 'whole' || main.type == 'half' || main.type == 'breve';
    final hasStem = main.type != 'whole' && main.type != 'breve';

    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final color = _colorFor(note);
      final y = _yForDiatonic(top, clef, note.diatonic);

      // Segundas no acorde: desloca a cabeça para o outro lado da haste.
      var hx = x;
      if (i > 0 && notes[i].diatonic - notes[i - 1].diatonic == 1) {
        hx = up ? x + headW : x - headW;
      }

      _paintLedgerLines(canvas, clef, note.diatonic, hx, top, headW);

      // Cabeça da nota (elipse inclinada).
      canvas.save();
      canvas.translate(hx + headW / 2, y);
      canvas.rotate(-0.33);
      final rect = Rect.fromCenter(center: Offset.zero, width: headW, height: headH);
      if (hollow) {
        canvas.drawOval(
          rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * (main.type == 'whole' ? 0.28 : 0.2),
        );
      } else {
        canvas.drawOval(rect, Paint()..color = color);
      }
      canvas.restore();

      // Acidente.
      final acc = _accidentalSymbol(note.accidental);
      if (acc != null) {
        _text(canvas, acc, Offset(hx - s * 1.35, y - s * 1.6), s * 2.4, music: true, color: color);
      }

      // Pontos de aumento (no espaço acima quando a nota está na linha).
      if (main.dots > 0) {
        final onLine = (note.diatonic - _bottomLine(clef)) % 2 == 0;
        final dy = onLine ? -s / 2 : 0.0;
        for (var d = 0; d < main.dots; d++) {
          canvas.drawCircle(
            Offset(x + headW + s * (0.55 + d * 0.5), y + dy),
            s * 0.18,
            Paint()..color = color,
          );
        }
      }
    }

    if (!hasStem) return null;

    final color = _colorFor(main);
    final lowY = _yForDiatonic(top, clef, notes.first.diatonic);
    final highY = _yForDiatonic(top, clef, notes.last.diatonic);
    final stemX = up ? x + headW - s * 0.06 : x + s * 0.06;
    final startY = up ? lowY : highY;
    final endY = up ? highY - s * 3.4 : lowY + s * 3.4;

    final info = _StemInfo(
      note: main,
      x: stemX,
      startY: startY,
      endY: endY,
      up: up,
      color: color,
      headX: x,
      headW: headW,
      lowY: lowY,
      highY: highY,
    );

    // Notas sem barra: desenha haste e bandeirolas imediatamente.
    if (main.beams.isEmpty) {
      _drawStem(canvas, info, endY);
      _paintFlags(canvas, info, endY);
    }
    return info;
  }

  void _drawStem(Canvas canvas, _StemInfo info, double endY) {
    canvas.drawLine(
      Offset(info.x, info.startY),
      Offset(info.x, endY),
      Paint()
        ..color = info.color
        ..strokeWidth = math.max(1, s * 0.12),
    );
  }

  int _flagCount(String type) => switch (type) {
        'eighth' => 1,
        '16th' => 2,
        '32nd' => 3,
        '64th' => 4,
        _ => 0,
      };

  void _paintFlags(Canvas canvas, _StemInfo info, double endY) {
    final count = _flagCount(info.note.type);
    final paint = Paint()
      ..color = info.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.3;
    for (var i = 0; i < count; i++) {
      final dir = info.up ? 1.0 : -1.0;
      final y0 = endY + dir * i * s * 0.9;
      final path = Path()
        ..moveTo(info.x, y0)
        ..quadraticBezierTo(info.x + s * 1.3, y0 + dir * s * 1.1, info.x + s * 0.9, y0 + dir * s * 2.6);
      canvas.drawPath(path, paint);
    }
  }

  void _paintBeams(Canvas canvas, List<_StemInfo> stems) {
    // Separa grupos pela marcação <beam number="1">.
    final groups = <List<_StemInfo>>[];
    List<_StemInfo>? current;
    for (final stem in stems) {
      final b = stem.note.beams[1];
      if (b == null) continue;
      if (b == 'begin' || current == null) {
        current = [stem];
        groups.add(current);
      } else {
        current.add(stem);
      }
      if (b == 'end') current = null;
    }

    for (final group in groups) {
      if (group.length < 2) {
        for (final stem in group) {
          _drawStem(canvas, stem, stem.endY);
          _paintFlags(canvas, stem, stem.endY);
        }
        continue;
      }

      // Direção única para o grupo (maioria).
      final up = group.where((g) => g.up).length * 2 >= group.length;
      final first = group.first;
      final last = group.last;

      // Pontas naturais das hastes na direção escolhida.
      double natural(_StemInfo g) => up ? g.startFor(up) - s * 3.4 : g.startFor(up) + s * 3.4;
      final x0 = first.xFor(up, s);
      final x1 = last.xFor(up, s);
      var y0 = natural(first);
      var y1 = natural(last);
      final maxSlope = s * 1.0;
      if ((y1 - y0).abs() > maxSlope) y1 = y0 + maxSlope * (y1 > y0 ? 1 : -1);

      // Garante hastes com comprimento mínimo.
      double beamY(double x) => x1 == x0 ? y0 : y0 + (y1 - y0) * (x - x0) / (x1 - x0);
      var shift = 0.0;
      for (final g in group) {
        final stemX = g.xFor(up, s);
        final len = up ? g.startFor(up) - beamY(stemX) : beamY(stemX) - g.startFor(up);
        if (len < s * 2.6) shift = math.max(shift, s * 2.6 - len);
      }
      if (up) {
        y0 -= shift;
        y1 -= shift;
      } else {
        y0 += shift;
        y1 += shift;
      }

      final color = group.first.color;
      final thickness = s * 0.48;
      final fill = Paint()..color = color;

      for (final g in group) {
        final stemX = g.xFor(up, s);
        canvas.drawLine(
          Offset(stemX, g.startFor(up)),
          Offset(stemX, beamY(stemX)),
          Paint()
            ..color = g.color
            ..strokeWidth = math.max(1, s * 0.12),
        );
      }

      // Barra principal.
      _drawBeamSegment(canvas, x0, x1, beamY, 0, up, thickness, fill);

      // Barras secundárias (semicolcheias).
      for (var level = 2; level <= 3; level++) {
        for (var i = 0; i < group.length; i++) {
          final value = group[i].note.beams[level];
          if (value == null) continue;
          final offset = (level - 1) * s * 0.8;
          if (value == 'forward hook' && i + 1 < group.length) {
            _drawBeamSegment(canvas, group[i].xFor(up, s), group[i].xFor(up, s) + s * 1.2, beamY, offset, up, thickness, fill);
          } else if (value == 'backward hook' && i > 0) {
            _drawBeamSegment(canvas, group[i].xFor(up, s) - s * 1.2, group[i].xFor(up, s), beamY, offset, up, thickness, fill);
          } else if ((value == 'begin' || value == 'continue') && i + 1 < group.length) {
            final next = group[i + 1].note.beams[level];
            if (next == 'continue' || next == 'end') {
              _drawBeamSegment(canvas, group[i].xFor(up, s), group[i + 1].xFor(up, s), beamY, offset, up, thickness, fill);
            }
          }
        }
      }
    }
  }

  void _drawBeamSegment(
    Canvas canvas,
    double xa,
    double xb,
    double Function(double) beamY,
    double offset,
    bool up,
    double thickness,
    Paint paint,
  ) {
    final dir = up ? 1.0 : -1.0;
    final ya = beamY(xa) + dir * offset;
    final yb = beamY(xb) + dir * offset;
    final path = Path()
      ..moveTo(xa, ya)
      ..lineTo(xb, yb)
      ..lineTo(xb, yb + dir * thickness)
      ..lineTo(xa, ya + dir * thickness)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintLedgerLines(Canvas canvas, String clef, int diatonic, double x, double top, double headW) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = math.max(1, s * 0.12);
    final bottomLine = _bottomLine(clef);
    final topLine = bottomLine + 8;

    for (var d = bottomLine - 2; d >= diatonic; d -= 2) {
      final y = _yForDiatonic(top, clef, d);
      canvas.drawLine(Offset(x - s * 0.45, y), Offset(x + headW + s * 0.45, y), paint);
    }
    for (var d = topLine + 2; d <= diatonic; d += 2) {
      final y = _yForDiatonic(top, clef, d);
      canvas.drawLine(Offset(x - s * 0.45, y), Offset(x + headW + s * 0.45, y), paint);
    }
  }

  String? _accidentalSymbol(String? accidental) => switch (accidental) {
        'sharp' => '♯',
        'flat' => '♭',
        'natural' => '♮',
        'double-sharp' => '𝄪',
        'flat-flat' => '𝄫',
        _ => null,
      };

  void _paintRest(Canvas canvas, ScoreNote rest, double x, double top, Color color) {
    final paint = Paint()..color = color;
    final mid = top + 2 * s;

    switch (rest.type) {
      case 'whole':
      case 'breve':
        // Pendurada na 4ª linha.
        canvas.drawRect(Rect.fromLTWH(x, top + s, s * 1.3, s * 0.55), paint);
        break;
      case 'half':
        // Apoiada na 3ª linha.
        canvas.drawRect(Rect.fromLTWH(x, mid - s * 0.55, s * 1.3, s * 0.55), paint);
        break;
      default:
        // Semínima e menores: glifos da fonte Noto Music.
        final glyph = switch (rest.type) {
          'quarter' => '𝄽',
          'eighth' => '𝄾',
          '16th' => '𝄿',
          _ => '𝅀',
        };
        _text(canvas, glyph, Offset(x, mid - s * 2.0), s * 4.0, music: true, color: color);
    }

    if (rest.dots > 0) {
      canvas.drawCircle(Offset(x + s * 1.8, mid - s * 0.5), s * 0.18, paint);
    }
  }

  // ------------------------------------------------------------------------
  // Ligaduras de prolongamento
  // ------------------------------------------------------------------------

  void _paintTies(Canvas canvas, SystemLayout system) {
    final visible = <ScoreNote>[];
    for (final ml in system.measures) {
      visible.addAll(score.measures[ml.measureIndex].notes.where((n) => !n.isRest));
    }
    final lastX = system.measures.last.endX;

    for (final note in visible.where((n) => n.tieStart)) {
      final ml = system.measures.firstWhere((m) => m.measureIndex == note.measureIndex);
      final measure = score.measures[note.measureIndex];
      final clef = measure.clefs[note.staff] ?? (note.staff == 1 ? 'G' : 'F');
      final top = layout.staffTop(system, note.staff);
      final x0 = (ml.onsetX[ScoreLayout._key(note.startBeat)] ?? ml.contentX) + s * 1.4;
      final y = _yForDiatonic(top, clef, note.diatonic);

      // Próxima nota de mesma altura que encerra a ligadura.
      final target = visible.where((n) =>
          n.tieStop && n.midi == note.midi && n.staff == note.staff && (n.startBeat - note.endBeat).abs() < 1e-3);
      double x1;
      if (target.isNotEmpty) {
        final t = target.first;
        final tm = system.measures.firstWhere((m) => m.measureIndex == t.measureIndex);
        x1 = (tm.onsetX[ScoreLayout._key(t.startBeat)] ?? tm.contentX) - s * 0.2;
      } else {
        x1 = lastX - s * 0.3;
      }

      final middle = _bottomLine(clef) + 4;
      final below = note.diatonic >= middle;
      final dir = below ? 1.0 : -1.0;
      final yy = y + dir * s * 0.9;
      final path = Path()
        ..moveTo(x0, yy)
        ..quadraticBezierTo((x0 + x1) / 2, yy + dir * s * 1.3, x1, yy);
      canvas.drawPath(
        path,
        Paint()
          ..color = _colorFor(note)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.16,
      );
    }
  }

  // ------------------------------------------------------------------------
  // Cursor
  // ------------------------------------------------------------------------

  void _paintCursor(Canvas canvas, SystemLayout system) {
    final beat = cursorBeat;
    if (beat == null) return;
    for (final ml in system.measures) {
      final m = score.measures[ml.measureIndex];
      if (beat < m.startBeat || beat >= m.endBeat) continue;
      final x = ml.xForBeat(beat, m.startBeat, m.endBeat);
      final top = layout.staffTop(system, 1) - s * 2;
      final bottom = layout.staffBottom(system, layout.staves) + s * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - s * 0.9, top, x + s * 2.1, bottom),
          Radius.circular(s * 0.6),
        ),
        Paint()..color = const Color(0xFF9B6DDA).withValues(alpha: 0.22),
      );
    }
  }

  // ------------------------------------------------------------------------
  // Texto
  // ------------------------------------------------------------------------

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize, {
    bool bold = false,
    bool music = false,
    Color color = _ink,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          height: 1.0,
          fontFamily: music ? 'NotoMusic' : null,
          fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ScorePainter old) {
    return old.score != score ||
        old.layout != layout ||
        old.noteColors != noteColors ||
        old.cursorBeat != cursorBeat ||
        old.evaluatedNoteIds != evaluatedNoteIds;
  }
}

class _StemInfo {
  final ScoreNote note;
  final double x;
  final double startY;
  final double endY;
  final bool up;
  final Color color;

  // Geometria das cabeças, para recalcular a haste em outra direção.
  final double headX;
  final double headW;
  final double lowY;
  final double highY;

  const _StemInfo({
    required this.note,
    required this.x,
    required this.startY,
    required this.endY,
    required this.up,
    required this.color,
    required this.headX,
    required this.headW,
    required this.lowY,
    required this.highY,
  });

  double xFor(bool up, double space) =>
      up ? headX + headW - space * 0.06 : headX + space * 0.06;

  double startFor(bool up) => up ? lowY : highY;
}
