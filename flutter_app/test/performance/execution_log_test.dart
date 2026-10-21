// Log da execução no console (feature execution_log) e pacotes do monitor
// serial do dispositivo.
import 'dart:typed_data';

import 'package:flutter_app/features/connection/data/protocol/device_protocol.dart';
import 'package:flutter_app/features/execution_log/domain/services/execution_console_log.dart';
import 'package:flutter_app/features/execution_log/domain/services/note_naming.dart';
import 'package:flutter_app/features/score/domain/entities/expected_note.dart';
import 'package:flutter_app/features/score/domain/entities/note_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nomes das notas e das figuras', () {
    expect(NoteNaming.pitch(60), 'C4');
    expect(NoteNaming.pitch(95), 'B6');
    expect(NoteNaming.pitch(61), 'C#4');
    expect(NoteNaming.figure(1).name, 'semínima');
    expect(NoteNaming.figure(0.5).name, 'colcheia');
    expect(NoteNaming.figure(0.125).name, 'fusa');
    expect(NoteNaming.figure(1.5).name, 'semínima pontuada');
    expect(NoteNaming.figure(4).name, 'semibreve');
    // Duração medida um pouco menor que a escrita continua sendo a figura
    expect(NoteNaming.figure(0.46).exact, isTrue);
    // Tercina de colcheia não é uma figura simples
    expect(NoteNaming.figure(1 / 3, tolerance: 0.05).exact, isFalse);
  });

  test('linha do som do app', () {
    final lines = <String>[];
    ExecutionConsoleLog(lines.add)
      ..audio(metronome: true, guide: false, playing: true)
      ..audio(metronome: true, guide: true, playing: false, error: 'NotAllowedError')
      ..audio(metronome: true, guide: false, playing: false)
      ..audio(metronome: false, guide: false, playing: false);
    expect(lines, [
      '[Áudio   ] metrônomo sonoro ligado, música guia desligada → tocando',
      '[Áudio   ] metrônomo sonoro ligado, música guia ligada → NÃO TOCOU: NotAllowedError',
      '[Áudio   ] metrônomo sonoro ligado, música guia desligada → NÃO TOCOU: o áudio não ficou pronto',
      '[Áudio   ] metrônomo sonoro desligado, música guia desligada → sem som do app (ligue em Configurações > Áudio)',
    ]);
  });

  test('linhas de esperado, captado e solta', () {
    final lines = <String>[];
    final log = ExecutionConsoleLog(lines.add);
    const note = ExpectedNote(
      index: 3,
      scoreNoteIds: [7],
      midi: 64,
      startBeat: 3,
      durationBeats: 1,
      phraseIndex: 0,
    );
    log.expected(note, onsetMs: 5400, durationMs: 600);
    log.captured(
      midi: 64,
      frequency: 329.6,
      timeMs: 5412,
      verdict: 'Perfeito!',
      comparison: const NoteComparison(
        expected: note,
        playedMidi: 64,
        playedFrequency: 329.6,
        onsetErrorMs: 12,
        playedDurationMs: null,
        expectedDurationMs: 600,
        pitchScore: 1,
        rhythmScore: 1,
        feedback: NoteFeedback.correct,
      ),
    );
    log.released(midi: 64, durationMs: 290, timeMs: 5702, quarterMs: 600);
    log.captured(midi: 60, frequency: 261.6, timeMs: 1000, comparison: null, verdict: '', countIn: true);

    expect(lines[0], contains('[Esperado] #3'));
    expect(lines[0], contains('E4'));
    expect(lines[0], contains('semínima'));
    expect(lines[0], contains('t=  5400 ms'));
    expect(lines[1], contains('[Captado ] E4'));
    expect(lines[1], contains('Perfeito! (esperado #3 E4, +12 ms)'));
    expect(lines[2], contains('solta: colcheia'));
    expect(lines[3], contains('contagem de entrada'));
  });

  test('pacote da nota esperada e denominador no início da sessão', () {
    final protocol = DeviceProtocol();
    final bytes = protocol.encodeExpectedNote(
      index: 12,
      midi: 60,
      onsetMs: 5400,
      durationMs: 600,
      durationBeats: 0.5,
    );
    final data = ByteData.sublistView(bytes);
    expect(bytes.length, 28);                       // sizeof(PktExpectedNote)
    expect(bytes[3], DeviceProtocol.expectedNote);
    expect(data.getUint16(12, Endian.little), 12);
    expect(bytes[14], 60);
    expect(data.getUint32(16, Endian.little), 5400);
    expect(data.getUint32(20, Endian.little), 600);
    expect(data.getUint16(24, Endian.little), 500);

    final start = protocol.encodeSessionStart(
      bpm: 100,
      beatsPerBar: 6,
      countInBars: 2,
      flags: 3,
      sessionId: 9,
      beatType: 8,
    );
    expect(start.length, 20);
    expect(start[17], 9);
    expect(start[18], 8);
  });
}
