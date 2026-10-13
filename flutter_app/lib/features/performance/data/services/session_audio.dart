import '../../../score/domain/services/score_analyzer.dart';
import '../../domain/services/performance_timeline.dart';
import 'audio_synth.dart';

// Áudio de uma execução (contagem de entrada, metrônomo e música guia) em um
// único arquivo, do início da sessão até o fim da música.
//
// Antes, a contagem e cada trecho eram arquivos separados: na passagem da
// contagem para a música (e de um trecho para o outro) o app trocava de
// arquivo, e o novo começava atrasado pelo ciclo da lógica (até 30 ms), pelo
// tempo de partida do player e pelo deslocamento do relógio da sessão
// (alinhado às batidas do dispositivo só depois da primeira batida). Com um
// arquivo só, a música começa na amostra exata em que a contagem termina.
// Um novo arquivo só é usado quando o andamento muda no meio da execução
// (a partir do trecho da mudança).
//
// Os cliques caem nos mesmos instantes e com o mesmo tempo forte das
// batidas do dispositivo (buzzer e LED): contagem de entrada e, depois, as
// batidas de cada frase no andamento dela (PerformanceTimeline).
class SessionAudioPlan {
  // Instante da sessão (ms) correspondente ao início do arquivo.
  final double baseMs;

  final SynthRequest request;

  const SessionAudioPlan(this.baseMs, this.request);

  bool get isEmpty => request.notes.isEmpty && request.clicks.isEmpty;

  // `fromPhrase`: primeira frase do arquivo. Com `countIn`, o arquivo começa
  // no início da sessão (contagem incluída); senão, no início da frase.
  static SessionAudioPlan build({
    required ScoreStructure structure,
    required PerformanceTimeline timeline,
    required int fromPhrase,
    required bool countIn,
    required bool countInClicks,
    required bool clicks,
    required bool guide,
    required ClickSound clickSound,
  }) {
    final beatsPerBar = structure.score.beatsPerBar;
    final baseMs = countIn ? 0.0 : timeline.phraseStartMs(fromPhrase);
    final synthClicks = <SynthClick>[];
    final notes = <SynthNote>[];

    if (countIn && countInClicks) {
      final beatMs = 60000 / timeline.metronomeBpmOf(timeline.startPhrase);
      for (var i = 0; i < timeline.countInBeats; i++) {
        synthClicks.add(SynthClick(timeMs: (i * beatMs).round(), accent: i % beatsPerBar == 0));
      }
    }

    if (clicks) {
      for (var p = fromPhrase; p < timeline.phrases.length; p++) {
        final start = timeline.phraseStartMs(p);
        final end = timeline.phraseEndMs(p);
        final beatMs = 60000 / timeline.metronomeBpmOf(p);
        final firstBeat = timeline.countInBeats + timeline.metronomeBeatsBetween(timeline.startPhrase, p);
        for (var i = 0; start + i * beatMs < end - 1; i++) {
          synthClicks.add(
            SynthClick(
              timeMs: (start + i * beatMs - baseMs).round(),
              accent: (firstBeat + i) % beatsPerBar == 0,
            ),
          );
        }
      }
    }

    if (guide) {
      final from = structure.phrases[fromPhrase].startBeat;
      for (final note in structure.score.notes) {
        // Continuações de ligadura não são reatacadas.
        if (note.isRest || note.tieStop) continue;
        if (note.startBeat < from - 1e-6) continue;
        notes.add(
          SynthNote(
            midi: note.midi,
            startMs: (timeline.beatToMs(note.startBeat) - baseMs).round(),
            durationMs: timeline.durationMs(note.startBeat, note.durationBeats).round(),
            velocity: structure.evaluatedNoteIds.contains(note.id) ? 0.8 : 0.55,
          ),
        );
      }
    }

    return SessionAudioPlan(
      baseMs,
      SynthRequest(
        notes: notes,
        clicks: synthClicks,
        totalMs: (timeline.endMs - baseMs).round(),
        clickSound: clickSound,
      ),
    );
  }
}
