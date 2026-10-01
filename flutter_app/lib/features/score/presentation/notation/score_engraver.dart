import 'dart:math' as math;
import 'dart:ui';

import '../../domain/entities/musical_score.dart';
import 'notation_items.dart';
import 'smufl.dart';

// ==========================================================================
// Motor de gravação (engraving) da partitura.
//
// Converte um trecho da partitura (lista de compassos) em primitivas de
// desenho posicionadas, seguindo as regras tradicionais de escrita musical:
//
//  1. Análise   – agrupa acordes, define a direção das hastes (por voz ou
//                 pela nota mais distante da linha central), desloca cabeças
//                 em intervalos de segunda, empilha acidentes e pontos.
//  2. Espaçamento – calcula a largura mínima e ideal de cada ataque
//                 (proporcional à duração, sem colisões) e distribui os
//                 compassos em sistemas (linhas) que cabem na largura.
//  3. Desenho   – gera claves, armaduras, fórmulas, cabeças, hastes,
//                 bandeirolas, barras de colcheia, linhas suplementares,
//                 ligaduras, pausas e barras de compasso.
//  4. Pautas    – calcula a distância entre as pautas pela extensão real
//                 das notas, evitando sobreposição.
//
// Todas as medidas internas estão em espaços de pauta (distância entre duas
// linhas) e são convertidas para pixels com `space`.
// ==========================================================================

// Posição horizontal de um compasso dentro de um sistema.
class MeasureSlot {
  final int measureIndex;
  final double x;
  final double width;

  // Início da área de notas (após clave/armadura/fórmula).
  final double contentX;

  // Instante (semínimas) -> posição x da cabeça das notas daquele ataque.
  final Map<double, double> onsetX;

  final double startBeat;
  final double endBeat;

  const MeasureSlot({
    required this.measureIndex,
    required this.x,
    required this.width,
    required this.contentX,
    required this.onsetX,
    required this.startBeat,
    required this.endBeat,
  });

  double get endX => x + width;

  // Converte um instante em posição x (interpolação entre os ataques).
  double xForBeat(double beat) {
    final entries = onsetX.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return contentX;
    if (beat <= entries.first.key) {
      final t = ((beat - startBeat) / math.max(1e-6, entries.first.key - startBeat)).clamp(0.0, 1.0);
      return contentX + (entries.first.value - contentX) * t;
    }
    for (var i = 0; i < entries.length - 1; i++) {
      final a = entries[i];
      final b = entries[i + 1];
      if (beat >= a.key && beat <= b.key) {
        final t = (beat - a.key) / (b.key - a.key);
        return a.value + (b.value - a.value) * t;
      }
    }
    final last = entries.last;
    final t = ((beat - last.key) / math.max(1e-6, endBeat - last.key)).clamp(0.0, 1.0);
    return last.value + (endX - last.value) * t;
  }
}

// Sistema: uma linha com todas as pautas.
class ScoreSystem {
  final double top;
  final double height;

  // Linha superior de cada pauta (índice 0 = pauta 1).
  final List<double> staffTops;

  final List<MeasureSlot> measures;
  final List<NotationItem> items;

  const ScoreSystem({
    required this.top,
    required this.height,
    required this.staffTops,
    required this.measures,
    required this.items,
  });

  double get bottom => top + height;
  double get startX => measures.first.x;
  double get endX => measures.last.endX;
}

// Resultado do layout de um trecho.
class EngravedScore {
  final double space;
  final double width;
  final double height;
  final int staves;
  final List<ScoreSystem> systems;

  // Posição das cabeças de nota (para destacar a nota atual).
  final Map<int, Rect> noteBounds;

  const EngravedScore({
    required this.space,
    required this.width,
    required this.height,
    required this.staves,
    required this.systems,
    required this.noteBounds,
  });

  // Sistema e posição x de um instante, ou null se fora do trecho.
  (ScoreSystem, double)? locate(double beat) {
    for (final system in systems) {
      for (final slot in system.measures) {
        if (beat >= slot.startBeat - 1e-9 && beat < slot.endBeat - 1e-9) {
          return (system, slot.xForBeat(beat));
        }
      }
    }
    return null;
  }
}

class ScoreEngraver {
  final MusicalScore score;

  ScoreEngraver(this.score);

  // Margens horizontais (espaços).
  static const _leftMargin = 1.8; // espaço para a chave do piano
  static const _rightMargin = 0.6;

  // Compressão máxima aceita do espaçamento ideal ao montar as linhas.
  static const _squeeze = 1.12;

  // Distância mínima entre pautas e margens verticais (espaços).
  static const _minStaffGap = 5.0;
  static const _minTopRoom = 3.0;
  static const _minBottomRoom = 2.0;

  EngravedScore engrave({
    required List<int> measureIndexes,
    required double width,
    double zoom = 1.0,
  }) {
    final indexes = measureIndexes.where((i) => i >= 0 && i < score.measures.length).toList();

    // Espaço de pauta proporcional à largura (símbolos ampliados – RFA04).
    var space = (width / 60).clamp(7.0, 12.0) * zoom;

    // Se algum compasso não couber nem com o espaçamento mínimo, reduz o
    // tamanho até caber (nenhum elemento pode sair da área visível).
    for (var attempt = 0; attempt < 6; attempt++) {
      final result = _engrave(indexes, width, space);
      if (result != null) return result;
      space *= 0.85;
    }
    return _engrave(indexes, width, space, force: true)!;
  }

  // ------------------------------------------------------------------------
  // Layout completo
  // ------------------------------------------------------------------------

  EngravedScore? _engrave(List<int> indexes, double width, double s, {bool force = false}) {
    final staves = score.staves.clamp(1, 4);
    final analyses = {for (final i in indexes) i: _MeasureAnalysis.build(score, i, staves)};

    final available = width / s - _leftMargin - _rightMargin;
    final lines = <List<int>>[];
    var current = <int>[];
    var used = 0.0;
    var usedMin = 0.0;

    for (final index in indexes) {
      final a = analyses[index]!;
      final first = current.isEmpty;
      final fragmentStart = lines.isEmpty && first;
      final w = a.naturalWidth(first: first, fragmentStart: fragmentStart);
      final wMin = a.minWidth(first: first, fragmentStart: fragmentStart);
      // Aceita comprimir um pouco o espaçamento ideal antes de quebrar a
      // linha (sem nunca ficar abaixo do espaçamento mínimo).
      if (!first && (used + w > available * _squeeze || usedMin + wMin > available)) {
        lines.add(current);
        current = [index];
        used = a.naturalWidth(first: true, fragmentStart: false);
        usedMin = a.minWidth(first: true, fragmentStart: false);
      } else {
        current.add(index);
        used += w;
        usedMin += wMin;
      }
    }
    if (current.isNotEmpty) lines.add(current);

    // Com a quantidade de linhas definida, redistribui os compassos para
    // que as linhas fiquem com preenchimento parecido (evita um compasso
    // sozinho e esticado na última linha).
    final balanced = _balance(indexes, analyses, available, lines.length);
    if (balanced != null) {
      lines
        ..clear()
        ..addAll(balanced);
    }

    // Verifica se cada linha cabe com o espaçamento mínimo.
    if (!force) {
      for (var l = 0; l < lines.length; l++) {
        var minWidth = 0.0;
        for (var i = 0; i < lines[l].length; i++) {
          minWidth += analyses[lines[l][i]]!.minWidth(first: i == 0, fragmentStart: l == 0 && i == 0);
        }
        if (minWidth > available + 1e-6) return null;
      }
    }

    final systems = <ScoreSystem>[];
    final noteBounds = <int, Rect>{};
    var top = 0.0;

    for (var l = 0; l < lines.length; l++) {
      final system = _SystemBuilder(
        score: score,
        analyses: analyses,
        line: lines[l],
        fragmentStart: l == 0,
        space: s,
        staves: staves,
        width: width,
        leftMargin: _leftMargin,
        rightMargin: _rightMargin,
      ).build(top, noteBounds);
      systems.add(system);
      top = system.bottom;
    }

    return EngravedScore(
      space: s,
      width: width,
      height: top,
      staves: staves,
      systems: systems,
      noteBounds: noteBounds,
    );
  }

  // Partição ótima dos compassos em `count` linhas consecutivas, que
  // minimiza a soma dos quadrados das sobras de cada linha.
  List<List<int>>? _balance(
    List<int> indexes,
    Map<int, _MeasureAnalysis> analyses,
    double available,
    int count,
  ) {
    final n = indexes.length;
    if (count <= 1 || count >= n) return null;

    double? cost(int from, int to) {
      var natural = 0.0;
      var minimum = 0.0;
      for (var i = from; i < to; i++) {
        final a = analyses[indexes[i]]!;
        final first = i == from;
        final fragmentStart = from == 0 && first;
        natural += a.naturalWidth(first: first, fragmentStart: fragmentStart);
        minimum += a.minWidth(first: first, fragmentStart: fragmentStart);
      }
      if (minimum > available || natural > available * _squeeze) return null;
      final slack = 1 - natural / available;
      return slack * slack;
    }

    // best[k][i] = menor custo para os i primeiros compassos em k linhas.
    final inf = double.infinity;
    final best = List.generate(count + 1, (_) => List.filled(n + 1, inf));
    final cut = List.generate(count + 1, (_) => List.filled(n + 1, -1));
    best[0][0] = 0;
    for (var k = 1; k <= count; k++) {
      for (var i = 1; i <= n; i++) {
        for (var j = k - 1; j < i; j++) {
          if (best[k - 1][j] == inf) continue;
          final c = cost(j, i);
          if (c == null) continue;
          final total = best[k - 1][j] + c;
          if (total < best[k][i]) {
            best[k][i] = total;
            cut[k][i] = j;
          }
        }
      }
    }
    if (best[count][n] == inf) return null;

    final result = <List<int>>[];
    var end = n;
    for (var k = count; k >= 1; k--) {
      final start = cut[k][end];
      result.insert(0, indexes.sublist(start, end));
      end = start;
    }
    return result;
  }

  // Distâncias verticais usadas pelo construtor de sistemas.
  static double get minStaffGap => _minStaffGap;
  static double get minTopRoom => _minTopRoom;
  static double get minBottomRoom => _minBottomRoom;
}

// ==========================================================================
// 1. ANÁLISE DE UM COMPASSO
// ==========================================================================

double _key(double beat) => (beat * 1000).roundToDouble() / 1000;

// Acorde (ou nota isolada, ou pausa) de uma voz.
class _Chord {
  final List<ScoreNote> notes; // ordem crescente de altura (vazio = pausa)
  final ScoreNote main; // primeira nota no arquivo (figura, pontos, barras)
  final int staff;
  final int voice;
  final double onset;

  bool up = true;
  bool multiVoice = false;
  bool upperVoice = true;

  // Deslocamento horizontal do acorde inteiro (vozes em colisão).
  double dx = 0;

  // Deslocamento de cada cabeça (segundas no acorde).
  final Map<int, double> headDx = {};

  // Posição x (relativa à cabeça) de cada acidente.
  final Map<int, double> accidentalX = {};

  // Grupo de barras de colcheia (-1 = sem barra).
  int beamGroup = -1;

  // Extensões à esquerda (negativa) e à direita da cabeça (espaços).
  double left = 0;
  double right = 0;

  _Chord({
    required this.notes,
    required this.main,
    required this.staff,
    required this.voice,
    required this.onset,
  });

  bool get isRest => notes.isEmpty;

  Clef get clef => main.clef;

  // Posição na pauta: 0 = linha inferior, 8 = linha superior.
  int stepsOf(ScoreNote n) => n.diatonic - n.clef.bottomLineDiatonic;

  int get lowSteps => stepsOf(notes.first);
  int get highSteps => stepsOf(notes.last);

  double get headWidth => _headWidth(main.type);

  bool get hasStem => !isRest && main.type != 'whole' && main.type != 'breve';

  int get flagCount => _flagCount(main.type);
}

double _headWidth(String type) => switch (type) {
      'breve' => Smufl.width(Smufl.noteheadDoubleWhole),
      'whole' => Smufl.width(Smufl.noteheadWhole),
      _ => Smufl.width(Smufl.noteheadBlack),
    };

int _headGlyph(String type) => switch (type) {
      'breve' => Smufl.noteheadDoubleWhole,
      'whole' => Smufl.noteheadWhole,
      'half' => Smufl.noteheadHalf,
      _ => Smufl.noteheadBlack,
    };

int _flagCount(String type) => switch (type) {
      'eighth' => 1,
      '16th' => 2,
      '32nd' => 3,
      '64th' => 4,
      _ => 0,
    };

int _restGlyph(String type) => switch (type) {
      'breve' => Smufl.restDoubleWhole,
      'whole' => Smufl.restWhole,
      'half' => Smufl.restHalf,
      'quarter' => Smufl.restQuarter,
      'eighth' => Smufl.rest8th,
      '16th' => Smufl.rest16th,
      '32nd' => Smufl.rest32nd,
      _ => Smufl.rest64th,
    };

int? _accidentalGlyph(String? accidental) => switch (accidental) {
      'sharp' => Smufl.accidentalSharp,
      'flat' => Smufl.accidentalFlat,
      'natural' => Smufl.accidentalNatural,
      'double-sharp' || 'sharp-sharp' => Smufl.accidentalDoubleSharp,
      'flat-flat' || 'double-flat' => Smufl.accidentalDoubleFlat,
      'natural-sharp' => Smufl.accidentalSharp,
      'natural-flat' => Smufl.accidentalFlat,
      _ => null,
    };

class _MeasureAnalysis {
  final ScoreMeasure measure;
  final List<_Chord> chords;

  // Ataques ordenados e extensões (espaços) de cada ataque.
  final List<double> onsets;
  final Map<double, double> leftOf;
  final Map<double, double> rightOf;

  // Pausas de compasso inteiro (desenhadas no centro).
  final List<ScoreNote> measureRests;

  // Grupos de barras de colcheia.
  final List<List<_Chord>> beamGroups;

  // Larguras dos cabeçalhos.
  final double fullHeader; // clave + armadura + fórmula (início de sistema)
  final double changeHeader; // mudanças no meio do sistema

  _MeasureAnalysis._({
    required this.measure,
    required this.chords,
    required this.onsets,
    required this.leftOf,
    required this.rightOf,
    required this.measureRests,
    required this.beamGroups,
    required this.fullHeader,
    required this.changeHeader,
  });

  static _MeasureAnalysis build(MusicalScore score, int index, int staves) {
    final measure = score.measures[index];
    final chords = <_Chord>[];
    final measureRests = <ScoreNote>[];

    // ---- Acordes ----
    for (final note in measure.notes) {
      if (note.staff > staves) continue;
      if (note.isRest) {
        if (note.isMeasureRest ||
            (note.durationBeats >= measure.durationBeats - 1e-6 && !note.hasRestPosition)) {
          measureRests.add(note);
          continue;
        }
        chords.add(_Chord(
          notes: [],
          main: note,
          staff: note.staff,
          voice: note.voice,
          onset: _key(note.startBeat),
        ));
        continue;
      }
      if (note.isChordMember && chords.isNotEmpty) {
        final last = chords.last;
        if (!last.isRest && last.staff == note.staff && last.voice == note.voice) {
          last.notes.add(note);
          continue;
        }
      }
      chords.add(_Chord(
        notes: [note],
        main: note,
        staff: note.staff,
        voice: note.voice,
        onset: _key(note.startBeat),
      ));
    }
    for (final chord in chords) {
      chord.notes.sort((a, b) => a.diatonic.compareTo(b.diatonic));
    }

    // ---- Vozes por pauta ----
    for (var staff = 1; staff <= staves; staff++) {
      final voices = {
        for (final c in chords.where((c) => c.staff == staff)) c.voice,
        for (final r in measureRests.where((r) => r.staff == staff)) r.voice,
      };
      if (voices.length > 1) {
        final upper = voices.reduce(math.min);
        for (final c in chords.where((c) => c.staff == staff)) {
          c.multiVoice = true;
          c.upperVoice = c.voice == upper;
        }
      }
    }

    // ---- Grupos de barras de colcheia (por pauta e voz) ----
    final beamGroups = <List<_Chord>>[];
    final open = <String, List<_Chord>>{};
    for (final chord in chords) {
      if (chord.isRest) continue;
      final value = chord.main.beams[1];
      final key = '${chord.staff}:${chord.voice}';
      if (value == null || chord.flagCount == 0) {
        open.remove(key);
        continue;
      }
      if (value == 'begin' || !open.containsKey(key)) {
        final group = <_Chord>[chord];
        open[key] = group;
        beamGroups.add(group);
      } else {
        open[key]!.add(chord);
      }
      if (value == 'end') open.remove(key);
    }
    beamGroups.removeWhere((g) => g.length < 2);
    for (var g = 0; g < beamGroups.length; g++) {
      for (final c in beamGroups[g]) {
        c.beamGroup = g;
      }
    }

    // ---- Direção das hastes ----
    bool byPosition(Iterable<_Chord> group) {
      var above = -100;
      var below = -100;
      for (final c in group) {
        above = math.max(above, c.highSteps - 4);
        below = math.max(below, 4 - c.lowSteps);
      }
      return below > above; // nota mais distante abaixo do centro -> haste para cima
    }

    bool directionFor(Iterable<_Chord> group) {
      final first = group.first;
      if (first.multiVoice) return first.upperVoice;
      final fileStem = group.map((c) => c.main.stem).whereType<String>().firstOrNull;
      if (fileStem == 'up') return true;
      if (fileStem == 'down') return false;
      return byPosition(group);
    }

    for (final group in beamGroups) {
      final up = directionFor(group);
      for (final c in group) {
        c.up = up;
      }
    }
    for (final c in chords) {
      if (c.isRest || c.beamGroup >= 0) continue;
      c.up = directionFor([c]);
    }

    // ---- Cabeças deslocadas (segundas) ----
    for (final c in chords) {
      if (c.isRest) continue;
      final w = c.headWidth;
      if (c.up) {
        var previous = -100;
        var previousShifted = false;
        for (final n in c.notes) {
          final steps = c.stepsOf(n);
          final shift = steps - previous == 1 && !previousShifted;
          c.headDx[n.id] = shift ? w : 0;
          previous = steps;
          previousShifted = shift;
        }
      } else {
        var previous = 100;
        var previousShifted = false;
        for (final n in c.notes.reversed) {
          final steps = c.stepsOf(n);
          final shift = previous - steps == 1 && !previousShifted;
          c.headDx[n.id] = shift ? -w : 0;
          previous = steps;
          previousShifted = shift;
        }
      }
    }

    // ---- Vozes que colidem no mesmo ataque ----
    final byOnset = <String, List<_Chord>>{};
    for (final c in chords.where((c) => !c.isRest)) {
      byOnset.putIfAbsent('${c.staff}:${c.onset}', () => []).add(c);
    }
    for (final group in byOnset.values) {
      if (group.length < 2) continue;
      final ups = group.where((c) => c.up).toList();
      final downs = group.where((c) => !c.up).toList();
      for (final d in downs) {
        for (final u in ups) {
          if (u.lowSteps - d.highSteps <= 1) {
            // Uníssono com a mesma figura compartilha a cabeça.
            final unison = u.lowSteps == d.highSteps && u.main.type == d.main.type &&
                u.notes.length == 1 && d.notes.length == 1 && u.main.dots == d.main.dots;
            if (!unison) d.dx = math.max(d.dx, u.headWidth + 0.1);
          }
        }
      }
    }

    // ---- Acidentes (colunas) ----
    for (final c in chords) {
      if (c.isRest) continue;
      final withAcc = c.notes.reversed.where((n) => _accidentalGlyph(n.accidental) != null).toList();
      if (withAcc.isEmpty) continue;
      final headLeft = c.notes.map((n) => c.headDx[n.id]!).reduce(math.min);
      final columns = <List<ScoreNote>>[];
      final columnOf = <int, int>{};
      for (final n in withAcc) {
        final glyph = _accidentalGlyph(n.accidental)!;
        var col = 0;
        while (true) {
          if (col >= columns.length) {
            columns.add([]);
            break;
          }
          final fits = columns[col].every((other) {
            final g2 = _accidentalGlyph(other.accidental)!;
            final upper = c.stepsOf(other) >= c.stepsOf(n) ? other : n;
            final lower = identical(upper, other) ? n : other;
            final gu = identical(upper, other) ? g2 : glyph;
            final gl = identical(lower, other) ? g2 : glyph;
            final gap = (c.stepsOf(upper) - c.stepsOf(lower)) / 2;
            return gap >= Smufl.top(gl) - Smufl.bottom(gu) - 0.1;
          });
          if (fits) break;
          col++;
        }
        columns[col].add(n);
        columnOf[n.id] = col;
      }
      var right = headLeft - 0.22;
      final colRight = <int, double>{};
      for (var col = 0; col < columns.length; col++) {
        colRight[col] = right;
        final widest = columns[col]
            .map((n) => Smufl.width(_accidentalGlyph(n.accidental)!))
            .reduce(math.max);
        right -= widest + 0.12;
      }
      for (final n in withAcc) {
        final glyph = _accidentalGlyph(n.accidental)!;
        c.accidentalX[n.id] = colRight[columnOf[n.id]]! - Smufl.width(glyph);
      }
    }

    // ---- Extensões de cada acorde ----
    for (final c in chords) {
      if (c.isRest) {
        final glyph = _restGlyph(c.main.type);
        c.left = 0;
        c.right = Smufl.width(glyph) + (c.main.dots > 0 ? 0.3 + c.main.dots * 0.5 : 0);
        continue;
      }
      final w = c.headWidth;
      var left = c.notes.map((n) => c.headDx[n.id]!).reduce(math.min);
      var right = c.notes.map((n) => c.headDx[n.id]! + w).reduce(math.max);
      if (c.accidentalX.isNotEmpty) left = math.min(left, c.accidentalX.values.reduce(math.min));
      if (c.main.dots > 0) right += 0.3 + c.main.dots * 0.5;
      if (c.up && c.beamGroup < 0 && c.flagCount > 0) {
        right = math.max(right, Smufl.stemAnchorX + 1.1);
      }
      c.left = left + c.dx;
      c.right = right + c.dx;
    }

    // ---- Ataques ----
    final onsetSet = <double>{for (final c in chords) c.onset};
    final onsets = onsetSet.toList()..sort();
    final leftOf = <double, double>{};
    final rightOf = <double, double>{};
    for (final c in chords) {
      leftOf[c.onset] = math.min(leftOf[c.onset] ?? 0, c.left);
      rightOf[c.onset] = math.max(rightOf[c.onset] ?? 0, c.right);
    }

    // Mudanças de clave no meio do compasso: espaço antes do ataque.
    for (final change in measure.clefChanges) {
      final beat = _key(change.beat);
      if (beat <= _key(measure.startBeat)) continue;
      final target = onsets.where((o) => o >= beat).firstOrNull;
      if (target != null) leftOf[target] = (leftOf[target] ?? 0) - 2.6;
    }

    // ---- Cabeçalhos ----
    final clefWidth = 2.8 + 0.6;
    final keyWidth = _keySignatureWidth(measure.fifths);
    final timeWidth = _timeSignatureWidth(measure);
    final fullHeader = 0.6 + clefWidth + (keyWidth > 0 ? keyWidth + 0.5 : 0);

    var change = 0.0;
    if (measure.clefChanges.any((c) => _key(c.beat) <= _key(measure.startBeat))) change += 2.4;
    if (measure.showKey && measure.index > 0) change += keyWidth + 0.8;
    if (measure.showTime && measure.index > 0) change += timeWidth + 0.8;

    return _MeasureAnalysis._(
      measure: measure,
      chords: chords,
      onsets: onsets,
      leftOf: leftOf,
      rightOf: rightOf,
      measureRests: measureRests,
      beamGroups: beamGroups,
      fullHeader: fullHeader + (timeWidth + 0.8),
      changeHeader: change,
    );
  }

  static double _keySignatureWidth(int fifths) {
    final n = fifths.abs().clamp(0, 7);
    if (n == 0) return 0;
    final glyph = fifths > 0 ? Smufl.accidentalSharp : Smufl.accidentalFlat;
    return n * (Smufl.width(glyph) + 0.15);
  }

  static double _timeSignatureWidth(ScoreMeasure m) {
    if (m.timeSymbol != null) return 1.8;
    double digits(int v) => '$v'.split('').fold(0.0, (s, d) => s + Smufl.width(Smufl.timeSig0 + int.parse(d)));
    return math.max(digits(m.beats), digits(m.beatType));
  }

  // Largura do cabeçalho deste compasso em uma posição do sistema.
  double header({required bool first, required bool fragmentStart}) {
    if (!first) return changeHeader;
    final withTime = fragmentStart || measure.showTime;
    return withTime ? fullHeader : fullHeader - (_timeSignatureWidth(measure) + 0.8);
  }

  // Distância ideal entre ataques, proporcional (logarítmica) à duração.
  static double idealGap(double beats) => 1.3 + 1.05 * (math.log(1 + beats / 0.25) / math.ln2);

  double get _padding => 1.3;

  // Distâncias ideais e mínimas a partir de cada ataque.
  List<double> gaps({required bool minimum}) {
    final result = <double>[];
    for (var i = 0; i < onsets.length; i++) {
      final next = i + 1 < onsets.length ? onsets[i + 1] : measure.endBeat;
      final dur = math.max(0.0625, next - onsets[i]);
      final minGap = (rightOf[onsets[i]] ?? 1.2) +
          (i + 1 < onsets.length ? -(leftOf[onsets[i + 1]] ?? 0) + 0.45 : 0.9);
      result.add(minimum ? minGap : math.max(minGap, idealGap(dur)));
    }
    return result;
  }

  double get _leadIn => _padding - (onsets.isEmpty ? 0 : (leftOf[onsets.first] ?? 0));

  double _contentWidth({required bool minimum}) {
    if (onsets.isEmpty) return measureRests.isNotEmpty ? 6.0 : 4.0;
    final sum = gaps(minimum: minimum).fold(0.0, (s, g) => s + g);
    return _leadIn + sum;
  }

  double naturalWidth({required bool first, required bool fragmentStart}) =>
      header(first: first, fragmentStart: fragmentStart) + _contentWidth(minimum: false);

  double minWidth({required bool first, required bool fragmentStart}) =>
      header(first: first, fragmentStart: fragmentStart) + _contentWidth(minimum: true);
}

// ==========================================================================
// 2–4. CONSTRUÇÃO DE UM SISTEMA
// ==========================================================================

class _SystemBuilder {
  final MusicalScore score;
  final Map<int, _MeasureAnalysis> analyses;
  final List<int> line;
  final bool fragmentStart;
  final double space;
  final int staves;
  final double width;
  final double leftMargin;
  final double rightMargin;

  _SystemBuilder({
    required this.score,
    required this.analyses,
    required this.line,
    required this.fragmentStart,
    required this.space,
    required this.staves,
    required this.width,
    required this.leftMargin,
    required this.rightMargin,
  });

  double get s => space;

  // Itens por pauta com y relativo à linha superior da pauta.
  late final List<List<NotationItem>> _staffItems = [for (var i = 0; i < staves; i++) []];

  // Posições das cabeças (y relativo) para ligaduras e destaques.
  final Map<int, _HeadPos> _heads = {};

  void _add(int staff, NotationItem item) => _staffItems[(staff - 1).clamp(0, staves - 1)].add(item);

  // y (relativo à linha superior) de uma posição na pauta.
  double _y(int steps) => (8 - steps) * s / 2;

  GlyphItem _glyph(int glyph, double x, double y, {List<int> ids = const [], double scale = 1}) {
    final size = 4 * s * scale;
    return GlyphItem(
      glyph: glyph,
      origin: Offset(x, y),
      fontSize: size,
      ascent: Smufl.top(glyph) * s * scale,
      descent: -Smufl.bottom(glyph) * s * scale,
      noteIds: ids,
    );
  }

  ScoreSystem build(double top, Map<int, Rect> noteBounds) {
    final slots = _layoutMeasures();

    for (var i = 0; i < line.length; i++) {
      final analysis = analyses[line[i]]!;
      _paintHeader(analysis, slots[i], first: i == 0);
      _paintMeasure(analysis, slots[i]);
    }
    _paintTies(slots);
    _paintTopTexts(slots);

    // ---- Distância entre pautas ----
    final staffTops = <double>[];
    var y = top;
    for (var i = 0; i < staves; i++) {
      final items = _staffItems[i];
      final minY = items.fold(0.0, (m, it) => math.min(m, it.minY));
      final maxY = items.fold(4 * s, (m, it) => math.max(m, it.maxY));
      if (i == 0) {
        y += math.max(ScoreEngraver.minTopRoom * s, -minY + s * 0.8);
      } else {
        final prevItems = _staffItems[i - 1];
        final prevMax = prevItems.fold(4 * s, (m, it) => math.max(m, it.maxY));
        final below = prevMax - 4 * s;
        final gap = math.max(ScoreEngraver.minStaffGap * s, below + (-minY) + s * 1.2);
        y = staffTops.last + 4 * s + gap;
      }
      staffTops.add(y);
      if (i == staves - 1) {
        final below = maxY - 4 * s;
        y = y + 4 * s + math.max(ScoreEngraver.minBottomRoom * s, below + s);
      }
    }

    // ---- Itens absolutos ----
    final items = <NotationItem>[];
    for (var i = 0; i < staves; i++) {
      for (final item in _staffItems[i]) {
        items.add(item.translate(0, staffTops[i]));
      }
    }
    for (final entry in _heads.entries) {
      final h = entry.value;
      final dy = staffTops[h.staff - 1];
      noteBounds[entry.key] = Rect.fromLTWH(h.x, h.y + dy - s / 2, h.width, s);
    }

    items.insertAll(0, _staffLinesAndBarlines(slots, staffTops));

    return ScoreSystem(
      top: top,
      height: y - top,
      staffTops: staffTops,
      measures: slots,
      items: items,
    );
  }

  // ------------------------------------------------------------------------
  // Espaçamento horizontal
  // ------------------------------------------------------------------------

  List<MeasureSlot> _layoutMeasures() {
    final available = width / s - leftMargin - rightMargin;

    final headers = <double>[];
    final ideal = <List<double>>[];
    final minimum = <List<double>>[];
    var fixed = 0.0;
    var flexible = 0.0;
    var minFlexible = 0.0;

    for (var i = 0; i < line.length; i++) {
      final a = analyses[line[i]]!;
      final h = a.header(first: i == 0, fragmentStart: fragmentStart && i == 0);
      headers.add(h);
      ideal.add(a.gaps(minimum: false));
      minimum.add(a.gaps(minimum: true));
      fixed += h + a._leadIn;
      if (a.onsets.isEmpty) {
        flexible += a._contentWidth(minimum: false);
        minFlexible += a._contentWidth(minimum: true);
      } else {
        flexible += ideal.last.fold(0.0, (x, g) => x + g);
        minFlexible += minimum.last.fold(0.0, (x, g) => x + g);
      }
    }

    // Distribui a sobra (ou a falta) proporcionalmente às distâncias ideais,
    // respeitando o mínimo de cada uma.
    final target = available - fixed;
    double scaleGap(double idealGap, double minGap) {
      if (flexible <= 0) return idealGap;
      if (target >= flexible) return idealGap * target / flexible;
      if (flexible - minFlexible <= 1e-9) return minGap;
      final t = ((target - minFlexible) / (flexible - minFlexible)).clamp(0.0, 1.0);
      return minGap + (idealGap - minGap) * t;
    }

    final slots = <MeasureSlot>[];
    var x = leftMargin * s;
    for (var i = 0; i < line.length; i++) {
      final a = analyses[line[i]]!;
      final m = a.measure;
      final contentX = x + headers[i] * s;
      final onsetX = <double, double>{};
      var cx = contentX + a._leadIn * s;
      var widthSpaces = headers[i] + a._leadIn;

      if (a.onsets.isEmpty) {
        final w = scaleGap(a._contentWidth(minimum: false), a._contentWidth(minimum: true)) - a._leadIn;
        widthSpaces += math.max(0, w);
      } else {
        for (var o = 0; o < a.onsets.length; o++) {
          onsetX[a.onsets[o]] = cx;
          final g = scaleGap(ideal[i][o], minimum[i][o]);
          cx += g * s;
          widthSpaces += g;
        }
      }

      slots.add(MeasureSlot(
        measureIndex: m.index,
        x: x,
        width: widthSpaces * s,
        contentX: contentX,
        onsetX: onsetX,
        startBeat: m.startBeat,
        endBeat: m.endBeat,
      ));
      x += widthSpaces * s;
    }
    return slots;
  }

  // ------------------------------------------------------------------------
  // Pautas, barras de compasso e chave
  // ------------------------------------------------------------------------

  List<NotationItem> _staffLinesAndBarlines(List<MeasureSlot> slots, List<double> tops) {
    final items = <NotationItem>[];
    final startX = slots.first.x;
    final endX = slots.last.endX;
    final lineWidth = Smufl.staffLineThickness * s;

    for (final top in tops) {
      for (var i = 0; i < 5; i++) {
        items.add(LineItem(
          a: Offset(startX, top + i * s),
          b: Offset(endX, top + i * s),
          width: lineWidth,
          structural: true,
        ));
      }
    }

    final systemTop = tops.first;
    final systemBottom = tops.last + 4 * s;
    final thin = Smufl.thinBarlineThickness * s;

    // Linha inicial que une as pautas.
    if (staves > 1) {
      items.add(LineItem(
        a: Offset(startX + thin / 2, systemTop),
        b: Offset(startX + thin / 2, systemBottom),
        width: thin,
        structural: true,
      ));

      // Chave do piano: o glifo tem 1 em de altura e é ampliado de modo
      // uniforme até cobrir todas as pautas.
      final height = systemBottom - systemTop;
      final braceWidth = Smufl.width(Smufl.brace) * height / 4;
      items.add(GlyphItem(
        glyph: Smufl.brace,
        origin: Offset(startX - braceWidth - s * 0.3, systemBottom),
        fontSize: height,
        ascent: height,
        descent: 0,
      ));
    }

    for (final slot in slots) {
      final isLast = slot.measureIndex == score.measures.length - 1;
      if (isLast) {
        final thick = Smufl.thickBarlineThickness * s;
        final thickX = slot.endX - thick;
        final thinX = thickX - Smufl.thinThickBarlineSeparation * s - thin / 2;
        items.add(LineItem(
          a: Offset(thinX, systemTop),
          b: Offset(thinX, systemBottom),
          width: thin,
          structural: true,
        ));
        items.add(PolygonItem(points: [
          Offset(thickX, systemTop),
          Offset(slot.endX, systemTop),
          Offset(slot.endX, systemBottom),
          Offset(thickX, systemBottom),
        ]));
      } else {
        items.add(LineItem(
          a: Offset(slot.endX - thin / 2, systemTop),
          b: Offset(slot.endX - thin / 2, systemBottom),
          width: thin,
          structural: true,
        ));
      }
    }
    return items;
  }

  // ------------------------------------------------------------------------
  // Clave, armadura e fórmula de compasso
  // ------------------------------------------------------------------------

  void _paintHeader(_MeasureAnalysis a, MeasureSlot slot, {required bool first}) {
    final m = a.measure;
    final withTime = first ? (fragmentStart || m.showTime) : (m.showTime && m.index > 0);
    final withKey = first ? m.fifths != 0 : (m.showKey && m.index > 0);
    final clefChangeAtStart = !first &&
        m.clefChanges.any((c) => _key(c.beat) <= _key(m.startBeat));

    for (var staff = 1; staff <= staves; staff++) {
      final clef = m.clefs[staff] ?? Clef.defaultFor(staff);
      var x = slot.x + 0.6 * s;

      if (first) {
        _paintClef(staff, clef, x, small: false);
        x += 3.4 * s;
      } else if (clefChangeAtStart) {
        final change = m.clefChanges.where((c) => c.staff == staff && _key(c.beat) <= _key(m.startBeat));
        if (change.isNotEmpty) _paintClef(staff, change.last.clef, x, small: true);
        x += 2.4 * s;
      }

      if (withKey) {
        x += _paintKeySignature(staff, clef, m.fifths, x) + 0.5 * s;
      }

      if (withTime) _paintTimeSignature(staff, m, x + 0.3 * s);
    }

    // Mudanças de clave no meio do compasso.
    for (final change in m.clefChanges) {
      final beat = _key(change.beat);
      if (beat <= _key(m.startBeat)) continue;
      final onset = a.onsets.where((o) => o >= beat).firstOrNull;
      final x = onset != null ? slot.onsetX[onset]! : slot.endX;
      final left = onset != null ? (a.leftOf[onset] ?? 0) + 2.6 : 0.0;
      _paintClef(change.staff, change.clef, x + (left - 2.4) * s, small: true);
    }
  }

  void _paintClef(int staff, Clef clef, double x, {required bool small}) {
    int glyph;
    switch (clef.sign) {
      case 'F':
        glyph = small ? Smufl.fClefChange : (clef.octaveChange == -1 ? Smufl.fClef8vb : Smufl.fClef);
      case 'C':
        glyph = small ? Smufl.cClefChange : Smufl.cClef;
      case 'G':
        glyph = small
            ? Smufl.gClefChange
            : switch (clef.octaveChange) {
                -1 => Smufl.gClef8vb,
                1 => Smufl.gClef8va,
                _ => Smufl.gClef,
              };
      default:
        _add(staff, _glyph(Smufl.unpitchedClef, x, _y(4)));
        return;
    }
    // A origem da clave fica sobre a linha da clave (linha 1 = inferior).
    final y = _y((clef.line - 1) * 2);
    _add(staff, _glyph(glyph, x, y));
  }

  // Posições (passos acima da linha inferior, clave de sol) dos acidentes
  // da armadura: F5 C5 G5 D5 A4 E5 B4 / B4 E5 A4 D5 G4 C5 F4.
  static const _sharpSteps = [8, 5, 9, 6, 3, 7, 4];
  static const _flatSteps = [4, 7, 3, 6, 2, 5, 1];

  double _paintKeySignature(int staff, Clef clef, int fifths, double x) {
    final n = fifths.abs().clamp(0, 7);
    if (n == 0) return 0;
    final glyph = fifths > 0 ? Smufl.accidentalSharp : Smufl.accidentalFlat;
    final positions = fifths > 0 ? _sharpSteps : _flatSteps;

    // Desloca o padrão da clave de sol para a clave atual (em oitavas).
    final treble = Clef.treble.bottomLineDiatonic;
    final shift = clef.bottomLineDiatonic - treble;
    final octaves = (shift / 7).round() * 7;
    final step = Smufl.width(glyph) + 0.15;

    for (var i = 0; i < n; i++) {
      var pos = positions[i] - (shift - octaves);
      if (pos > 9) pos -= 7;
      if (pos < -1) pos += 7;
      _add(staff, _glyph(glyph, x + i * step * s, _y(pos)));
    }
    return n * step * s;
  }

  void _paintTimeSignature(int staff, ScoreMeasure m, double x) {
    if (m.timeSymbol != null) {
      final glyph = m.timeSymbol == 'cut' ? Smufl.timeSigCutCommon : Smufl.timeSigCommon;
      _add(staff, _glyph(glyph, x, _y(4)));
      return;
    }
    final top = '${m.beats}';
    final bottom = '${m.beatType}';
    double widthOf(String v) => v.split('').fold(0.0, (w, d) => w + Smufl.width(Smufl.timeSig0 + int.parse(d)));
    final total = math.max(widthOf(top), widthOf(bottom));

    void number(String value, int steps) {
      var cx = x + (total - widthOf(value)) / 2 * s;
      for (final d in value.split('')) {
        final glyph = Smufl.timeSig0 + int.parse(d);
        _add(staff, _glyph(glyph, cx, _y(steps)));
        cx += Smufl.width(glyph) * s;
      }
    }

    number(top, 6);
    number(bottom, 2);
  }

  // ------------------------------------------------------------------------
  // Notas, pausas, hastes e barras
  // ------------------------------------------------------------------------

  void _paintMeasure(_MeasureAnalysis a, MeasureSlot slot) {
    // Informações das hastes de cada acorde (para as barras de colcheia).
    final stems = <_Chord, _StemGeom>{};

    for (final c in a.chords) {
      final x = slot.onsetX[c.onset]! + c.dx * s;
      if (c.isRest) {
        _paintRest(c, x);
        continue;
      }
      final stem = _paintChord(c, x);
      if (stem != null) stems[c] = stem;
    }

    // Hastes sem barra: haste + bandeirolas.
    for (final entry in stems.entries) {
      final c = entry.key;
      if (c.beamGroup >= 0) continue;
      final g = entry.value;
      _add(c.staff, LineItem(a: Offset(g.x, g.startY), b: Offset(g.x, g.endY), width: Smufl.stemThickness * s, noteIds: g.ids));
      if (c.flagCount > 0) {
        final glyph = Smufl.flag(c.flagCount, up: c.up);
        final fx = g.x - Smufl.stemThickness * s / 2;
        _add(c.staff, _glyph(glyph, fx, g.endY, ids: g.ids));
      }
    }

    for (final group in a.beamGroups) {
      _paintBeamGroup(group, stems);
    }

    // Pausas de compasso inteiro: centralizadas.
    for (final rest in a.measureRests) {
      final hasVoices = a.chords.any((c) => c.staff == rest.staff) ||
          a.measureRests.where((r) => r.staff == rest.staff).length > 1;
      final upper = !hasVoices || rest.voice == a.measureRests.where((r) => r.staff == rest.staff).map((r) => r.voice).reduce(math.min);
      final glyph = Smufl.restWhole;
      final center = (slot.contentX + slot.endX) / 2;
      final x = center - Smufl.width(glyph) * s / 2;
      final steps = hasVoices ? (upper ? 8 : 2) : 6;
      _add(rest.staff, _glyph(glyph, x, _y(steps), ids: [rest.id]));
    }
  }

  void _paintRest(_Chord c, double x) {
    final rest = c.main;
    final glyph = _restGlyph(rest.type);
    int steps;
    if (rest.hasRestPosition) {
      steps = c.stepsOf(rest);
      if (rest.type == 'whole') steps += 2;
      steps = steps.clamp(-4, 12);
    } else {
      steps = rest.type == 'whole' ? 6 : 4;
      if (c.multiVoice) steps += c.upperVoice ? 4 : -4;
    }
    final y = _y(steps);
    _add(c.staff, _glyph(glyph, x, y, ids: [rest.id]));

    // Linha suplementar para semibreve/mínima fora da pauta.
    if ((rest.type == 'whole' || rest.type == 'half') && (steps > 8 || steps < 0)) {
      _add(c.staff, LineItem(
        a: Offset(x - 0.4 * s, y),
        b: Offset(x + (Smufl.width(glyph) + 0.4) * s, y),
        width: Smufl.legerLineThickness * s,
      ));
    }

    for (var d = 0; d < rest.dots; d++) {
      _add(c.staff, _glyph(
        Smufl.augmentationDot,
        x + (Smufl.width(glyph) + 0.3 + d * 0.5) * s,
        _y(steps.isEven ? steps + 1 : steps),
        ids: [rest.id],
      ));
    }
  }

  _StemGeom? _paintChord(_Chord c, double x) {
    final w = c.headWidth;
    final glyph = _headGlyph(c.main.type);
    final ids = [for (final n in c.notes) n.id];

    // Linhas suplementares (uma vez por acorde).
    final legerWidth = Smufl.legerLineThickness * s;
    final ext = Smufl.legerLineExtension * s;
    for (final above in [true, false]) {
      final beyond = c.notes.where((n) => above ? c.stepsOf(n) >= 10 : c.stepsOf(n) <= -2).toList();
      if (beyond.isEmpty) continue;
      final extreme = above ? beyond.map(c.stepsOf).reduce(math.max) : beyond.map(c.stepsOf).reduce(math.min);
      for (var steps = above ? 10 : -2; above ? steps <= extreme : steps >= extreme; steps += above ? 2 : -2) {
        // Cabeças que alcançam esta linha.
        final reaching = beyond.where((n) => above ? c.stepsOf(n) >= steps - 1 : c.stepsOf(n) <= steps + 1);
        final lefts = reaching.map((n) => c.headDx[n.id]!).toList();
        final minDx = lefts.isEmpty ? 0.0 : lefts.reduce(math.min);
        final maxDx = lefts.isEmpty ? 0.0 : lefts.reduce(math.max);
        _add(c.staff, LineItem(
          a: Offset(x + minDx * s - ext, _y(steps)),
          b: Offset(x + (maxDx + w) * s + ext, _y(steps)),
          width: legerWidth,
        ));
      }
    }

    // Cabeças, acidentes e pontos.
    final dotYs = <int>{};
    for (final n in c.notes) {
      final steps = c.stepsOf(n);
      final hx = x + c.headDx[n.id]! * s;
      final y = _y(steps);
      _add(c.staff, _glyph(glyph, hx, y, ids: [n.id]));
      _heads[n.id] = _HeadPos(staff: c.staff, x: hx, y: y, width: w * s, up: c.up, chord: c);

      final accX = c.accidentalX[n.id];
      if (accX != null) {
        final acc = _accidentalGlyph(n.accidental)!;
        _add(c.staff, _glyph(acc, x + accX * s, y, ids: [n.id]));
      }

      if (c.main.dots > 0) {
        var dotSteps = steps.isEven ? steps + 1 : steps;
        if (steps.isEven && c.multiVoice && !c.upperVoice) dotSteps = steps - 1;
        if (dotYs.add(dotSteps)) {
          final rightMost = c.notes.map((o) => c.headDx[o.id]!).reduce(math.max) + w;
          for (var d = 0; d < c.main.dots; d++) {
            _add(c.staff, _glyph(
              Smufl.augmentationDot,
              x + (rightMost + 0.3 + d * 0.5) * s,
              _y(dotSteps),
              ids: [n.id],
            ));
          }
        }
      }
    }

    if (!c.hasStem) return null;

    // Haste: presa à cabeça normal (não deslocada) do acorde.
    final st = Smufl.stemThickness * s;
    final stemX = c.up ? x + Smufl.stemAnchorX * s - st / 2 : x + st / 2;
    final lowY = _y(c.lowSteps);
    final highY = _y(c.highSteps);
    final extra = math.max(0, c.flagCount - 2) * 0.5;
    double endY;
    if (c.up) {
      endY = highY - (3.5 + extra) * s;
      endY = math.min(endY, _y(4)); // alcança a linha central
    } else {
      endY = lowY + (3.5 + extra) * s;
      endY = math.max(endY, _y(4));
    }
    final startY = c.up ? lowY - Smufl.stemAnchorY * s : highY + Smufl.stemAnchorY * s;
    return _StemGeom(x: stemX, startY: startY, endY: endY, ids: ids, nearY: c.up ? highY : lowY);
  }

  void _paintBeamGroup(List<_Chord> group, Map<_Chord, _StemGeom> stems) {
    final geoms = [for (final c in group) stems[c]].whereType<_StemGeom>().toList();
    if (geoms.length < 2) return;
    final up = group.first.up;
    final staff = group.first.staff;
    final dir = up ? -1.0 : 1.0; // direção das hastes na tela

    final first = geoms.first;
    final last = geoms.last;
    final x0 = first.x;
    final x1 = last.x;

    // Inclinação: segue as notas extremas, limitada a 1 espaço; contorno
    // côncavo (nota interna mais extrema) deixa a barra horizontal.
    var slope = 0.0;
    if (x1 - x0 > 1e-6) {
      final dy = last.nearY - first.nearY;
      final inner = geoms.sublist(1, geoms.length - 1);
      final concave = inner.any((g) => up
          ? g.nearY < math.min(first.nearY, last.nearY) - 1e-6
          : g.nearY > math.max(first.nearY, last.nearY) + 1e-6);
      if (!concave && dy.abs() > 1e-6) {
        final limited = dy.sign * math.min(dy.abs() * 0.5, s);
        slope = limited / (x1 - x0);
      }
    }

    final levels = group.map((c) => c.flagCount).reduce(math.max);
    final minStem = (3.0 + math.max(0, levels - 2) * 0.75) * s;
    final beamGap = (Smufl.beamThickness + Smufl.beamSpacing) * s;

    // Posição: a haste mais curta deve ter o comprimento mínimo.
    double lineAt(double x, double base) => base + slope * (x - x0);
    var base = first.nearY + dir * 3.5 * s;
    for (final g in geoms) {
      final target = g.nearY + dir * minStem;
      final y = lineAt(g.x, base);
      if (up && y > target) base -= y - target;
      if (!up && y < target) base += target - y;
    }
    // Hastes de notas muito afastadas: a barra alcança a linha central.
    final middle = _y(4);
    final mid = lineAt((x0 + x1) / 2, base);
    if (up && mid > middle) base -= mid - middle;
    if (!up && mid < middle) base += middle - mid;

    final st = Smufl.stemThickness * s;
    for (var i = 0; i < geoms.length; i++) {
      final g = geoms[i];
      _add(staff, LineItem(a: Offset(g.x, g.startY), b: Offset(g.x, lineAt(g.x, base)), width: st, noteIds: g.ids));
    }

    final allIds = [for (final g in geoms) ...g.ids];
    final thickness = Smufl.beamThickness * s;

    void segment(double xa, double xb, int level) {
      final offset = -dir * (level - 1) * beamGap; // barras extras em direção às notas
      final ya = lineAt(xa, base) + offset;
      final yb = lineAt(xb, base) + offset;
      final t = -dir * thickness;
      _add(staff, PolygonItem(
        points: [Offset(xa, ya), Offset(xb, yb), Offset(xb, yb + t), Offset(xa, ya + t)],
        noteIds: allIds,
        colorOnlyIfUniform: true,
      ));
    }

    segment(x0 - st / 2, x1 + st / 2, 1);

    // Barras secundárias (semicolcheias, fusas...).
    for (var level = 2; level <= levels; level++) {
      for (var i = 0; i < group.length; i++) {
        final c = group[i];
        if (c.flagCount < level || stems[c] == null) continue;
        final value = c.main.beams[level];
        final gx = stems[c]!.x;
        final hasNext = i + 1 < group.length && group[i + 1].flagCount >= level && stems[group[i + 1]] != null;
        final hasPrev = i > 0 && group[i - 1].flagCount >= level && stems[group[i - 1]] != null;

        if (hasNext && (value == null || value == 'begin' || value == 'continue')) {
          final nextValue = group[i + 1].main.beams[level];
          if (value != null || nextValue == null || nextValue == 'continue' || nextValue == 'end') {
            segment(gx - st / 2, stems[group[i + 1]]!.x + st / 2, level);
            continue;
          }
        }
        final linkedPrev = hasPrev && (value == 'end' || value == 'continue' || value == null);
        if (linkedPrev) continue; // já desenhada a partir da nota anterior
        // Ganchos (barra parcial).
        final hookRight = value == 'forward hook' || (value != 'backward hook' && i == 0);
        if (hookRight) {
          segment(gx - st / 2, gx + 1.1 * s, level);
        } else {
          segment(gx - 1.1 * s, gx + st / 2, level);
        }
      }
    }
  }

  // ------------------------------------------------------------------------
  // Ligaduras de prolongamento
  // ------------------------------------------------------------------------

  void _paintTies(List<MeasureSlot> slots) {
    final systemStart = slots.first.contentX - 0.5 * s;
    final systemEnd = slots.last.endX - 0.3 * s;

    bool above(_HeadPos h, ScoreNote n) {
      final c = h.chord;
      if (c.notes.length > 1) {
        // Em acordes, notas da metade superior ligam por cima.
        final index = c.notes.indexWhere((o) => o.id == n.id);
        return index >= c.notes.length / 2;
      }
      return !c.up;
    }

    final visible = <ScoreNote>[];
    for (final slot in slots) {
      visible.addAll(score.measures[slot.measureIndex].notes.where((n) => !n.isRest && _heads.containsKey(n.id)));
    }

    for (final note in visible) {
      final head = _heads[note.id]!;
      final isAbove = above(head, note);
      final dy = (isAbove ? -0.55 : 0.55) * s;

      if (note.tieStart) {
        final target = visible.where((n) =>
            n.tieStop &&
            n.staff == note.staff &&
            n.midi == note.midi &&
            (n.startBeat - note.endBeat).abs() < 1e-3);
        final x0 = head.x + head.width + 0.12 * s;
        final x1 = target.isNotEmpty ? _heads[target.first.id]!.x - 0.12 * s : systemEnd;
        if (x1 > x0) {
          _add(note.staff, TieItem(
            start: Offset(x0, head.y + dy),
            end: Offset(x1, head.y + dy),
            above: isAbove,
            space: s,
            noteIds: [note.id],
          ));
        }
      }

      // Ligadura que vem do sistema anterior.
      if (note.tieStop) {
        final source = visible.where((n) =>
            n.tieStart &&
            n.staff == note.staff &&
            n.midi == note.midi &&
            (note.startBeat - n.endBeat).abs() < 1e-3);
        if (source.isEmpty && head.x - 0.12 * s > systemStart) {
          _add(note.staff, TieItem(
            start: Offset(systemStart, head.y + dy),
            end: Offset(head.x - 0.12 * s, head.y + dy),
            above: isAbove,
            space: s,
            noteIds: [note.id],
          ));
        }
      }
    }
  }

  // ------------------------------------------------------------------------
  // Andamento e número do compasso
  // ------------------------------------------------------------------------

  void _paintTopTexts(List<MeasureSlot> slots) {
    final items = _staffItems[0];
    final highest = items.fold(0.0, (m, it) => math.min(m, it.minY));
    final baseline = math.min(-1.6 * s, highest - 0.8 * s);
    final size = 1.5 * s;

    final first = score.measures[slots.first.measureIndex];
    if (first.index > 0) {
      _add(1, TextItem(
        text: first.number,
        origin: Offset(slots.first.x, baseline),
        size: size * 0.85,
        italic: true,
        muted: true,
      ));
    }

    if (first.index == 0 && score.tempo != null) {
      final x = slots.first.contentX + 0.5 * s;
      _add(1, _glyph(Smufl.metNoteQuarterUp, x, baseline - 0.2 * s, scale: 0.75));
      _add(1, TextItem(
        text: '= ${score.tempo}',
        origin: Offset(x + 1.4 * s, baseline),
        size: size,
      ));
    }
  }
}

class _StemGeom {
  final double x;
  final double startY;
  final double endY;
  final List<int> ids;

  // Cabeça mais próxima da barra (define o comprimento mínimo da haste).
  final double nearY;

  const _StemGeom({
    required this.x,
    required this.startY,
    required this.endY,
    required this.ids,
    required this.nearY,
  });
}

class _HeadPos {
  final int staff;
  final double x;
  final double y;
  final double width;
  final bool up;
  final _Chord chord;

  const _HeadPos({
    required this.staff,
    required this.x,
    required this.y,
    required this.width,
    required this.up,
    required this.chord,
  });
}
