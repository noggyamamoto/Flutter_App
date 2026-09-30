import 'dart:io';

import 'package:flutter_app/features/score/domain/services/musicxml_parser.dart';
import 'package:flutter_app/features/score/domain/services/score_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

const _simpleXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <work><work-title>Teste</work-title></work>
  <identification><creator type="composer">Autor</creator></identification>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <key><fifths>1</fifths></key>
        <time><beats>3</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction><sound tempo="90"/></direction>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><chord/><pitch><step>E</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>eighth</type><accidental>sharp</accidental><staff>1</staff><beam number="1">begin</beam></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>eighth</type><staff>1</staff><beam number="1">end</beam></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration><tie type="start"/><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <backup><duration>6</duration></backup>
      <note><pitch><step>G</step><octave>2</octave></pitch><duration>6</duration><voice>2</voice><type>half</type><dot/><staff>2</staff></note>
    </measure>
    <measure number="2">
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration><tie type="stop"/><voice>1</voice><type>quarter</type><staff>1</staff></note>
      <note><rest/><duration>4</duration><voice>1</voice><type>half</type><staff>1</staff></note>
      <backup><duration>6</duration></backup>
      <note><rest measure="yes"/><duration>6</duration><voice>2</voice><staff>2</staff></note>
    </measure>
  </part>
</score-partwise>''';

void main() {
  group('MusicXmlParser', () {
    test('lê atributos, vozes, acordes e ligaduras', () {
      final score = MusicXmlParser().parse(_simpleXml);

      expect(score.title, 'Teste');
      expect(score.composer, 'Autor');
      expect(score.staves, 2);
      expect(score.tempo, 90);
      expect(score.measures, hasLength(2));
      expect(score.beatsPerBar, 3);
      expect(score.measures[0].fifths, 1);
      expect(score.measures[0].clefs, {1: 'G', 2: 'F'});
      expect(score.measures[1].startBeat, 3);

      final m1 = score.measures[0].notes;
      // Acorde: E5 começa junto com C5
      expect(m1[1].isChordMember, isTrue);
      expect(m1[1].startBeat, 0);
      expect(m1[2].midi, 66); // F#4
      expect(m1[2].startBeat, 1);
      expect(m1[2].accidental, 'sharp');
      expect(m1[2].beams[1], 'begin');
      // Voz da mão esquerda volta ao início pelo <backup>
      final bass = m1.last;
      expect(bass.staff, 2);
      expect(bass.startBeat, 0);
      expect(bass.durationBeats, 3);
      expect(bass.dots, 1);
      expect(score.measures[1].notes.last.type, 'whole');
    });

    test('extrai a melodia somando ligaduras', () {
      final score = MusicXmlParser().parse(_simpleXml);
      final structure = ScoreAnalyzer().analyze(score, measuresPerPhrase: 1);

      final melody = structure.expectedNotes;
      expect(melody.map((n) => n.midi).toList(), [76, 66, 67, 69]);
      expect(melody.last.durationBeats, 2); // A4 ligado entre compassos
      expect(melody.last.scoreNoteIds, hasLength(2));
      expect(structure.phrases, hasLength(2));
    });

    test('rejeita arquivos que não são MusicXML', () {
      expect(
        () => MusicXmlParser().parse('<html></html>'),
        throwsFormatException,
      );
      expect(() => MusicXmlParser().parse('nada'), throwsFormatException);
    });

    test('carrega todas as partituras do repertório', () {
      final dir = Directory('assets/partituras');
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.xml'));
      expect(files, isNotEmpty);

      for (final file in files) {
        final score = MusicXmlParser().parse(file.readAsStringSync());
        final structure = ScoreAnalyzer().analyze(score);

        expect(score.staves, 2, reason: file.path);
        expect(structure.expectedNotes, isNotEmpty, reason: file.path);
        expect(structure.phrases.last.lastMeasure, score.measures.length - 1);

        // Compassos consecutivos e notas dentro dos limites do compasso.
        for (final m in score.measures) {
          for (final n in m.notes) {
            expect(n.startBeat, greaterThanOrEqualTo(m.startBeat - 1e-6));
            expect(n.endBeat, lessThanOrEqualTo(m.endBeat + 1e-6));
          }
        }
        // ignore: avoid_print
        print('${file.path}: ${score.measures.length} compassos, '
            '${structure.phrases.length} frases, '
            '${structure.expectedNotes.length} notas avaliadas, '
            'extensão ${structure.expectedNotes.map((n) => n.midi).reduce((a, b) => a < b ? a : b)}'
            '-${structure.expectedNotes.map((n) => n.midi).reduce((a, b) => a > b ? a : b)}');
      }
    });
  });
}
