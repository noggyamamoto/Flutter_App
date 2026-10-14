import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';
import '../../domain/entities/performance_history.dart';

class PerformanceHistoryModel {
  // ID do documento da execução.
  final String executionId;

  // ID da partitura.
  final String songId;

  // Data e hora da execução.
  final DateTime date;

  // Pontuação final.
  final double score;

  // BPM inicial.
  final int bpm;

  // Status da execução.
  final String status;

  // Precisão de altura e de ritmo.
  final double? pitchScore;
  final double? rhythmScore;

  // BPM final.
  final int? finalBpm;

  // Contagem de notas.
  final int? notesPlayed;
  final int? notesCorrect;
  final int? notesExpected;
  final int? extraNotes;

  // Maior sequência de acertos.
  final int? bestStreak;

  // Compassos por trecho.
  final int? measuresPerPhrase;

  // Avaliação de cada trecho.
  final List<PhraseResult> phrases;

  // Resultado de cada nota.
  final Map<int, NoteFeedback> noteFeedback;

  const PerformanceHistoryModel({
    required this.executionId,
    required this.songId,
    required this.date,
    required this.score,
    required this.bpm,
    required this.status,
    this.pitchScore,
    this.rhythmScore,
    this.finalBpm,
    this.notesPlayed,
    this.notesCorrect,
    this.notesExpected,
    this.extraNotes,
    this.bestStreak,
    this.measuresPerPhrase,
    this.phrases = const [],
    this.noteFeedback = const {},
  });

  // Converte os dados vindos do Firestore para o Model.
  factory PerformanceHistoryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    // Recupera o valor do campo dataHora.
    final timestamp = map['dataHora'];

    // Se o Firestore enviou um Timestamp,
    // convertemos para DateTime.
    final date = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.now();

    return PerformanceHistoryModel(
      // ID do documento.
      executionId:
          map['executionId'] as String? ?? '',

      // ID da partitura.
      songId:
          map['idPartitura'] as String? ?? '',

      // Data da execução.
      date: date,

      // Pontuação.
      score: (map['pontuacaoFinal'] as num?)
              ?.toDouble() ??
          0,

      // BPM inicial.
      bpm: (map['bpmInicial'] as num?)?.toInt() ?? 0,

      // Status.
      status:
          map['status'] as String? ?? '',

      // Detalhes da avaliação (execuções antigas não possuem).
      pitchScore:
          (map['pontuacaoAltura'] as num?)?.toDouble(),
      rhythmScore:
          (map['pontuacaoRitmo'] as num?)?.toDouble(),
      finalBpm:
          (map['bpmFinal'] as num?)?.toInt(),
      notesPlayed:
          (map['notasTocadas'] as num?)?.toInt(),
      notesCorrect:
          (map['notasCorretas'] as num?)?.toInt(),
      notesExpected:
          (map['notasEsperadas'] as num?)?.toInt(),
      extraNotes:
          (map['notasExtras'] as num?)?.toInt(),
      bestStreak:
          (map['maiorSequencia'] as num?)?.toInt(),
      measuresPerPhrase:
          (map['compassosPorTrecho'] as num?)?.toInt(),

      // Trechos e resultado de cada nota.
      phrases: phrasesFromList(map['trechos']),
      noteFeedback: feedbackFromMap(map['resultadoNotas']),
    );
  }

  // Converte o Model para a Entity.
  PerformanceHistory toEntity() {
    return PerformanceHistory(
      executionId: executionId,
      songId: songId,
      date: date,
      score: score,
      bpm: bpm,
      status: status,
      pitchScore: pitchScore,
      rhythmScore: rhythmScore,
      finalBpm: finalBpm,
      notesPlayed: notesPlayed,
      notesCorrect: notesCorrect,
      notesExpected: notesExpected,
      extraNotes: extraNotes,
      bestStreak: bestStreak,
      measuresPerPhrase: measuresPerPhrase,
      phrases: phrases,
      noteFeedback: noteFeedback,
    );
  }

  // -------------------------------------------------------
  // TRECHOS (campo "trechos")
  // -------------------------------------------------------

  static Map<String, Object> phraseToMap(PhraseResult phrase) {
    return {
      'indice': phrase.phraseIndex,
      'altura': phrase.pitchAccuracy,
      'ritmo': phrase.rhythmAccuracy,
      'pontuacao': phrase.score,
      'esperadas': phrase.notesExpected,
      'corretas': phrase.notesCorrect,
      'perdidas': phrase.notesMissed,
      'extras': phrase.extraNotes,
      'desvioMs': phrase.timingDeviationMs,
      'instavel': phrase.unstable,
    };
  }

  static List<PhraseResult> phrasesFromList(Object? value) {
    if (value is! List) return const [];
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    return [
      for (final item in value)
        if (item is Map)
          PhraseResult(
            phraseIndex: i(item['indice']),
            pitchAccuracy: d(item['altura']),
            rhythmAccuracy: d(item['ritmo']),
            score: d(item['pontuacao']),
            notesExpected: i(item['esperadas']),
            notesCorrect: i(item['corretas']),
            notesMissed: i(item['perdidas']),
            extraNotes: i(item['extras']),
            timingDeviationMs: d(item['desvioMs']),
            unstable: item['instavel'] == true,
          ),
    ];
  }

  // -------------------------------------------------------
  // RESULTADO DE CADA NOTA (campo "resultadoNotas")
  // -------------------------------------------------------

  // Id da nota (texto) -> resultado ("correct", "approximate"...).
  // Notas ainda pendentes não são salvas.
  static Map<String, String> feedbackToMap(Map<int, NoteFeedback> feedback) {
    return {
      for (final entry in feedback.entries)
        if (entry.value != NoteFeedback.pending) '${entry.key}': entry.value.name,
    };
  }

  static Map<int, NoteFeedback> feedbackFromMap(Object? value) {
    if (value is! Map) return const {};
    final feedback = <int, NoteFeedback>{};
    value.forEach((key, name) {
      final id = int.tryParse('$key');
      final result = NoteFeedback.values.where((f) => f.name == name).firstOrNull;
      if (id != null && result != null) feedback[id] = result;
    });
    return feedback;
  }
}
