import '../../../score/domain/entities/expected_note.dart';
import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';
import 'note_naming.dart';

// Log da execução no console (no navegador: DevTools > Console).
//
// Durante a execução mostra, em ordem de tempo e no relógio da sessão do
// dispositivo (0 ms = primeira batida da contagem de entrada):
//  - [Esperado] cada nota da partitura quando chega a hora dela, com o nome
//    (C4, B6...) e a figura (semínima, colcheia, fusa...);
//  - [Captado ] cada nota recebida do microfone, com a frequência, o
//    instante, o resultado da comparação e, ao soltar, a figura
//    correspondente à duração medida;
//  - [Perdida ] notas esperadas que não foram tocadas;
//  - o resumo de cada trecho e o resultado final.
class ExecutionConsoleLog {
  final void Function(String line) _sink;

  ExecutionConsoleLog(this._sink);

  static String _ms(int ms) => ms.toString().padLeft(6);

  static String _col(String text, int width) => text.padRight(width);

  void start({
    required int bpm,
    required int metronomeBpm,
    required int beatsPerBar,
    required int beatType,
    required int countInBars,
    required int countInMs,
    required int fromPhrase,
    required bool simulated,
  }) {
    _sink('[Execução] Início${fromPhrase > 0 ? ' no trecho ${fromPhrase + 1}' : ''}: '
        '$bpm BPM (metrônomo $metronomeBpm), compasso $beatsPerBar/$beatType, '
        'contagem de $countInBars compasso(s) = $countInMs ms '
        '(${simulated ? 'modo demonstração' : 'dispositivo'}). '
        'Tempos no relógio do dispositivo; a música começa em t=$countInMs ms.');
  }

  void expected(ExpectedNote note, {required int onsetMs, required int durationMs}) {
    final figure = NoteNaming.figure(note.durationBeats, tolerance: 0.05);
    _sink('[Esperado] #${_col('${note.index}', 4)} ${_col(NoteNaming.pitch(note.midi), 4)} '
        '${_col(figure.exact ? figure.name : 'quiáltera ($figure)', 24)} '
        't=${_ms(onsetMs)} ms  dur ${durationMs.toString().padLeft(4)} ms');
  }

  void captured({
    required int midi,
    required double frequency,
    required int timeMs,
    required NoteComparison? comparison,
    required String verdict,
    bool countIn = false,
  }) {
    final String detail;
    if (countIn) {
      detail = '(contagem de entrada: ignorada)';
    } else if (comparison == null) {
      detail = '→ $verdict (nenhuma nota esperada na janela)';
    } else {
      final expected = comparison.expected;
      final error = comparison.onsetErrorMs ?? 0;
      detail = '→ $verdict (esperado #${expected.index} ${NoteNaming.pitch(expected.midi)}, '
          '${error >= 0 ? '+' : ''}$error ms)';
    }
    _sink('[Captado ] ${_col(NoteNaming.pitch(midi), 4)} '
        '${_col('${frequency.toStringAsFixed(1)} Hz', 30)} t=${_ms(timeMs)} ms  $detail');
  }

  void released({
    required int midi,
    required int durationMs,
    required int timeMs,
    required double quarterMs,
  }) {
    final figure = NoteNaming.figure(durationMs / quarterMs);
    _sink('[Captado ] ${_col(NoteNaming.pitch(midi), 4)} '
        '${_col('solta: $figure', 30)} t=${_ms(timeMs)} ms  dur $durationMs ms');
  }

  void missed(NoteComparison comparison, {required int onsetMs}) {
    final note = comparison.expected;
    final figure = NoteNaming.figure(note.durationBeats, tolerance: 0.05);
    _sink('[Perdida ] #${_col('${note.index}', 4)} ${_col(NoteNaming.pitch(note.midi), 4)} '
        '${_col(figure.toString(), 24)} t=${_ms(onsetMs)} ms  (não foi captada)');
  }

  void phrase(PhraseResult result) {
    _sink('[Trecho  ] ${result.phraseIndex + 1}: ${result.score.toStringAsFixed(0)}% '
        '(altura ${result.pitchAccuracy.toStringAsFixed(0)}%, '
        'ritmo ${result.rhythmAccuracy.toStringAsFixed(0)}%) – '
        '${result.notesCorrect}/${result.notesExpected} corretas, '
        '${result.notesMissed} perdidas, ${result.extraNotes} extras'
        '${result.failed ? ' – abaixo de 50%: repetir o trecho' : ''}');
  }

  void finish(ScoreResult result) {
    _sink('[Execução] ${result.completed ? 'Concluída' : 'Interrompida'}: '
        'geral ${result.overall.toStringAsFixed(1)}%, '
        'altura ${result.pitchAccuracy.toStringAsFixed(1)}%, '
        'ritmo ${result.rhythmAccuracy.toStringAsFixed(1)}% – '
        '${result.notesCorrect}/${result.notesExpected} corretas, '
        '${result.notesPlayed} tocadas, ${result.extraNotes} extras');
  }
}
