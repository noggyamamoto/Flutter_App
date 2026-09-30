import 'package:xml/xml.dart';

import '../entities/musical_score.dart';

// Converte um arquivo MusicXML (score-partwise) em MusicalScore.
//
// Suporta: múltiplas pautas (piano), vozes com <backup>/<forward>,
// acordes, pausas, pontos, ligaduras, barras de colcheia, acidentes,
// mudanças de armadura/fórmula/clave e andamento em <sound tempo>.
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

    // Estado que se propaga de um compasso para o outro.
    var divisions = 1.0;
    var beats = 4;
    var beatType = 4;
    var fifths = 0;
    var staves = 1;
    int? tempo;
    final clefs = <int, String>{1: 'G'};

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
      final notes = <ScoreNote>[];

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
              if (b != null && bt != null) {
                if (b != beats || bt != beatType) showTime = true;
                beats = b;
                beatType = bt;
              }
            }

            final st = _int(child.getElement('staves'));
            if (st != null) staves = st;

            for (final clef in child.findElements('clef')) {
              final number = int.tryParse(clef.getAttribute('number') ?? '1') ?? 1;
              final sign = _text(clef.getElement('sign')) ?? 'G';
              clefs[number] = sign;
            }
            break;

          case 'direction':
            final t = double.tryParse(
              child.getElement('sound')?.getAttribute('tempo') ?? '',
            );
            if (t != null && tempo == null) tempo = t.round();
            break;

          case 'sound':
            final t = double.tryParse(child.getAttribute('tempo') ?? '');
            if (t != null && tempo == null) tempo = t.round();
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
            // Apojaturas (grace) não ocupam tempo e não são avaliadas.
            if (child.getElement('grace') != null) break;

            final isChord = child.getElement('chord') != null;
            final duration =
                (_double(child.getElement('duration')) ?? 0) / divisions;
            final start = isChord ? lastNoteStart : cursor;

            final pitch = child.getElement('pitch');
            final isRest = child.getElement('rest') != null || pitch == null;

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

            final type = _text(child.getElement('type')) ??
                _typeFromDuration(duration);

            // Pausa de compasso inteiro sem <type> é desenhada como semibreve.
            final measureRest =
                child.getElement('rest')?.getAttribute('measure') == 'yes';

            notes.add(
              ScoreNote(
                id: noteId++,
                measureIndex: index,
                staff: _int(child.getElement('staff')) ?? 1,
                voice: _int(child.getElement('voice')) ?? 1,
                startBeat: measureStart + start,
                durationBeats: duration,
                isRest: isRest,
                isChordMember: isChord,
                step: _text(pitch?.getElement('step')) ?? 'B',
                alter: _double(pitch?.getElement('alter'))?.round() ?? 0,
                octave: _int(pitch?.getElement('octave')) ?? 4,
                type: measureRest ? 'whole' : type,
                dots: child.findElements('dot').length,
                accidental: _text(child.getElement('accidental')),
                tieStart: ties.contains('start') || tieds.contains('start'),
                tieStop: ties.contains('stop') || tieds.contains('stop'),
                beams: beamMap,
                stem: _text(child.getElement('stem')),
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
          clefs: Map.of(clefs),
          notes: notes,
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
      staves: staves,
      tempo: tempo,
      measures: measures,
    );
  }

  // Deduz a figura pela duração quando <type> não é informado.
  String _typeFromDuration(double beats) {
    if (beats >= 4) return 'whole';
    if (beats >= 2) return 'half';
    if (beats >= 1) return 'quarter';
    if (beats >= 0.5) return 'eighth';
    if (beats >= 0.25) return '16th';
    return '32nd';
  }

  String? _text(XmlElement? element) {
    final text = element?.innerText.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  int? _int(XmlElement? element) => int.tryParse(_text(element) ?? '');

  double? _double(XmlElement? element) =>
      double.tryParse(_text(element) ?? '');
}
