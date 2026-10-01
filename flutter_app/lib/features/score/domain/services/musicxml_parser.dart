import 'package:xml/xml.dart';

import '../entities/musical_score.dart';

// Converte um arquivo MusicXML (score-partwise) em MusicalScore.
//
// Suporta: múltiplas pautas (piano), vozes com <backup>/<forward>,
// acordes, pausas (inclusive de compasso inteiro e com posição definida),
// pontos, ligaduras, barras de colcheia, mudanças de armadura, fórmula e
// clave (inclusive no meio do compasso e claves com transposição de
// oitava) e andamento em <sound tempo>/<metronome>.
//
// Acidentes: quando o arquivo traz <accidental>, ele é respeitado; quando
// não traz, o acidente é calculado pela armadura de clave e pelos acidentes
// já usados no compasso (regra tradicional de escrita).
//
// Quando o arquivo possui várias partes, somente a primeira é usada.
class MusicXmlParser {
  MusicalScore parse(String xmlText) {
    final XmlDocument document;

    try {
      document = XmlDocument.parse(xmlText);
    } on XmlException catch (e) {
      throw FormatException('Arquivo MusicXML inválido: ${e.message}');
    }

    final root = document.rootElement;

    if (root.name.local == 'score-timewise') {
      throw const FormatException(
        'Formato score-timewise não suportado. '
        'Exporte a partitura como MusicXML "partwise".',
      );
    }

    if (root.name.local != 'score-partwise') {
      throw const FormatException(
        'O arquivo não é uma partitura MusicXML.',
      );
    }

    final title = _text(root.getElement('work')?.getElement('work-title')) ??
        _text(root.getElement('movement-title')) ??
        '';

    final composer = root
            .getElement('identification')
            ?.findElements('creator')
            .where((e) => e.getAttribute('type') == 'composer')
            .map((e) => e.innerText.trim())
            .firstWhere((t) => t.isNotEmpty, orElse: () => '') ??
        '';

    final part = root.findElements('part').firstOrNull;

    if (part == null) {
      throw const FormatException('A partitura não possui partes.');
    }

    final partId = part.getAttribute('id');
    final partName = root
            .getElement('part-list')
            ?.findElements('score-part')
            .where((e) => e.getAttribute('id') == partId)
            .map((e) => _text(e.getElement('part-name')) ?? '')
            .firstOrNull ??
        '';

    // Estado que se propaga de um compasso para o outro.
    var divisions = 1.0;
    var beats = 4;
    var beatType = 4;
    String? timeSymbol;
    var fifths = 0;
    var staves = 1;
    int? tempo;
    final clefs = <int, Clef>{};

    var measureStart = 0.0;
    var noteId = 0;
    final measures = <ScoreMeasure>[];

    for (final measureEl in part.findElements('measure')) {
      final index = measures.length;
      var cursor = 0.0; // Posição dentro do compasso (semínimas)
      var maxCursor = 0.0;
      var lastNoteStart = 0.0;
      var showTime = index == 0;
      var showKey = index == 0;
      final measureClefs = <int, Clef>{};
      final clefChanges = <ClefChange>[];
      final notes = <ScoreNote>[];

      Clef clefOf(int staff) => clefs[staff] ?? Clef.defaultFor(staff);

      // Claves vigentes no início do compasso.
      for (var s = 1; s <= staves; s++) {
        measureClefs[s] = clefOf(s);
      }

      for (final child in measureEl.childElements) {
        switch (child.name.local) {
          case 'attributes':
            final div = _double(child.getElement('divisions'));
            if (div != null && div > 0) divisions = div;

            final key = child.getElement('key');
            final f = _int(key?.getElement('fifths'));
            if (f != null) {
              if (f != fifths) showKey = true;
              fifths = f;
            }

            final time = child.getElement('time');
            if (time != null) {
              final b = int.tryParse(
                _text(time.getElement('beats'))?.split('+').first ?? '',
              );
              final bt = _int(time.getElement('beat-type'));
              final symbol = time.getAttribute('symbol');
              if (b != null && bt != null) {
                if (b != beats || bt != beatType) showTime = true;
                beats = b;
                beatType = bt;
                timeSymbol = symbol == 'common' || symbol == 'cut' ? symbol : null;
              }
            }

            final st = _int(child.getElement('staves'));
            if (st != null && st > 0) {
              staves = st;
              for (var s = 1; s <= staves; s++) {
                measureClefs.putIfAbsent(s, () => clefOf(s));
              }
            }

            for (final clefEl in child.findElements('clef')) {
              final number = int.tryParse(clefEl.getAttribute('number') ?? '1') ?? 1;
              final sign = (_text(clefEl.getElement('sign')) ?? 'G').toUpperCase();
              final defaultLine = switch (sign) {
                'F' => 4,
                'C' => 3,
                _ => 2,
              };
              final clef = Clef(
                sign,
                _int(clefEl.getElement('line')) ?? defaultLine,
                octaveChange: _int(clefEl.getElement('clef-octave-change')) ?? 0,
              );
              final previous = clefs[number];
              clefs[number] = clef;

              if (cursor <= 1e-9 && notes.every((n) => n.staff != number)) {
                // Clave no início do compasso: passa a valer para o compasso.
                measureClefs[number] = clef;
                if (index > 0 && previous != null && previous != clef) {
                  clefChanges.add(ClefChange(staff: number, beat: measureStart, clef: clef));
                }
              } else if (previous != clef) {
                clefChanges.add(
                  ClefChange(staff: number, beat: measureStart + cursor, clef: clef),
                );
              }
            }
            break;

          case 'direction':
            var t = double.tryParse(
              child.getElement('sound')?.getAttribute('tempo') ?? '',
            );
            if (t == null) {
              // <metronome> sem <sound>: usa o valor exibido.
              final metronome = child
                  .findElements('direction-type')
                  .map((e) => e.getElement('metronome'))
                  .whereType<XmlElement>()
                  .firstOrNull;
              final unit = _text(metronome?.getElement('beat-unit'));
              final perMinute = _double(metronome?.getElement('per-minute'));
              if (perMinute != null) {
                final factor = switch (unit) {
                  'half' => 2.0,
                  'eighth' => 0.5,
                  'whole' => 4.0,
                  _ => 1.0,
                };
                final dotted = metronome!.getElement('beat-unit-dot') != null;
                t = perMinute * factor * (dotted ? 1.5 : 1.0);
              }
            }
            if (t != null && t > 0 && tempo == null) tempo = t.round();
            break;

          case 'sound':
            final t = double.tryParse(child.getAttribute('tempo') ?? '');
            if (t != null && t > 0 && tempo == null) tempo = t.round();
            break;

          case 'backup':
            cursor -= (_double(child.getElement('duration')) ?? 0) / divisions;
            if (cursor < 0) cursor = 0;
            break;

          case 'forward':
            cursor += (_double(child.getElement('duration')) ?? 0) / divisions;
            if (cursor > maxCursor) maxCursor = cursor;
            break;

          case 'note':
            // Apojaturas (grace) e notas de referência (cue) não ocupam
            // tempo e não são avaliadas.
            if (child.getElement('grace') != null || child.getElement('cue') != null) {
              break;
            }

            final isChord = child.getElement('chord') != null;
            final duration =
                (_double(child.getElement('duration')) ?? 0) / divisions;
            final start = isChord ? lastNoteStart : cursor;

            final pitch = child.getElement('pitch');
            final restEl = child.getElement('rest');
            final unpitched = child.getElement('unpitched');
            final isRest = restEl != null || (pitch == null && unpitched == null);

            final ties = child.findElements('tie').map((e) => e.getAttribute('type'));
            final tieds = child
                    .getElement('notations')
                    ?.findElements('tied')
                    .map((e) => e.getAttribute('type')) ??
                const Iterable<String?>.empty();

            final beamMap = <int, String>{};
            for (final beam in child.findElements('beam')) {
              final level = int.tryParse(beam.getAttribute('number') ?? '1') ?? 1;
              beamMap[level] = beam.innerText.trim();
            }

            final staff = _int(child.getElement('staff')) ?? 1;
            final type = _text(child.getElement('type')) ?? _typeFromDuration(duration);

            // Pausa de compasso inteiro: atributo measure="yes" ou pausa
            // sem figura que ocupa o compasso todo.
            final nominal = beats * 4 / beatType;
            final measureRest = restEl != null &&
                (restEl.getAttribute('measure') == 'yes' ||
                    (child.getElement('type') == null && duration >= nominal - 1e-6));

            // Altura (nota), posição (pausa com display-step) ou nota sem
            // altura definida (percussão).
            final positionEl = pitch ?? restEl ?? unpitched;
            final step = _text(pitch?.getElement('step')) ??
                _text(positionEl?.getElement('display-step')) ??
                'B';
            final octave = _int(pitch?.getElement('octave')) ??
                _int(positionEl?.getElement('display-octave')) ??
                4;

            notes.add(
              ScoreNote(
                id: noteId++,
                measureIndex: index,
                staff: staff,
                voice: _int(child.getElement('voice')) ?? 1,
                startBeat: measureStart + start,
                durationBeats: duration,
                isRest: isRest,
                isChordMember: isChord,
                step: step.toUpperCase(),
                alter: _double(pitch?.getElement('alter'))?.round() ?? 0,
                octave: octave,
                type: measureRest ? 'whole' : type,
                dots: child.findElements('dot').length,
                accidental: _text(child.getElement('accidental')),
                tieStart: ties.contains('start') || tieds.contains('start'),
                tieStop: ties.contains('stop') || tieds.contains('stop'),
                beams: beamMap,
                stem: _text(child.getElement('stem')),
                clef: clefOf(staff),
                isMeasureRest: measureRest,
                hasRestPosition: restEl?.getElement('display-step') != null,
              ),
            );

            if (!isChord) {
              lastNoteStart = cursor;
              cursor += duration;
              if (cursor > maxCursor) maxCursor = cursor;
            }
            break;
        }
      }

      // Duração do compasso: conteúdo real (anacruse) ou fórmula vigente.
      final nominal = beats * 4 / beatType;
      final implicit = measureEl.getAttribute('implicit') == 'yes';
      final duration = maxCursor > 0
          ? (implicit ? maxCursor : (maxCursor > nominal ? maxCursor : nominal))
          : nominal;

      measures.add(
        ScoreMeasure(
          index: index,
          number: measureEl.getAttribute('number') ?? '${index + 1}',
          startBeat: measureStart,
          durationBeats: duration,
          beats: beats,
          beatType: beatType,
          fifths: fifths,
          showTime: showTime,
          showKey: showKey,
          clefs: Map.of(measureClefs),
          clefChanges: clefChanges,
          timeSymbol: timeSymbol,
          notes: _resolveAccidentals(notes, fifths),
        ),
      );

      measureStart += duration;
    }

    if (measures.isEmpty) {
      throw const FormatException('A partitura não possui compassos.');
    }

    return MusicalScore(
      title: title,
      composer: composer,
      partName: partName,
      staves: staves,
      tempo: tempo,
      measures: measures,
    );
  }

  // Ordem dos sustenidos e bemóis na armadura.
  static const _sharpSteps = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
  static const _flatSteps = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];

  // Alteração que a armadura aplica a cada nota.
  static int keyAlter(int fifths, String step) {
    if (fifths > 0 && _sharpSteps.take(fifths).contains(step)) return 1;
    if (fifths < 0 && _flatSteps.take(-fifths).contains(step)) return -1;
    return 0;
  }

  static String? accidentalName(int alter) => switch (alter) {
        2 => 'double-sharp',
        1 => 'sharp',
        0 => 'natural',
        -1 => 'flat',
        -2 => 'flat-flat',
        _ => null,
      };

  // Define o acidente desenhado em cada nota do compasso.
  //
  // Um acidente vale até o fim do compasso para a mesma nota (altura e
  // oitava) da mesma pauta. Notas que continuam uma ligadura não repetem o
  // acidente.
  List<ScoreNote> _resolveAccidentals(List<ScoreNote> notes, int fifths) {
    final order = [for (var i = 0; i < notes.length; i++) i]..sort((a, b) {
        final byTime = notes[a].startBeat.compareTo(notes[b].startBeat);
        return byTime != 0 ? byTime : a.compareTo(b);
      });

    final shown = <String, int>{};
    final result = List<ScoreNote>.of(notes);

    for (final i in order) {
      final note = notes[i];
      if (note.isRest) continue;

      final key = '${note.staff}:${note.step}${note.octave}';
      final current = shown[key] ?? keyAlter(fifths, note.step);
      String? accidental = note.accidental;

      if (accidental == null && !note.tieStop && note.alter != current) {
        accidental = accidentalName(note.alter);
      }

      shown[key] = note.alter;
      if (accidental != note.accidental) result[i] = note.withAccidental(accidental);
    }

    return result;
  }

  // Deduz a figura pela duração quando <type> não é informado.
  String _typeFromDuration(double beats) {
    if (beats >= 8) return 'breve';
    if (beats >= 4) return 'whole';
    if (beats >= 2) return 'half';
    if (beats >= 1) return 'quarter';
    if (beats >= 0.5) return 'eighth';
    if (beats >= 0.25) return '16th';
    if (beats >= 0.125) return '32nd';
    return '64th';
  }

  String? _text(XmlElement? element) {
    final text = element?.innerText.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  int? _int(XmlElement? element) => int.tryParse(_text(element) ?? '');

  double? _double(XmlElement? element) =>
      double.tryParse(_text(element) ?? '');
}
