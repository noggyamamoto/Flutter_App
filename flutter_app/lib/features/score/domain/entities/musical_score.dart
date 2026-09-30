// Representação simbólica de uma partitura carregada de um arquivo MusicXML.
//
// Todas as posições e durações são medidas em semínimas (tempos de 1/4),
// independentemente das "divisions" usadas no arquivo.

// Nota (ou pausa) de uma pauta.
class ScoreNote {
  // Identificador sequencial dentro da partitura.
  final int id;

  // Índice do compasso (0 = primeiro).
  final int measureIndex;

  // Pauta (1 = superior / clave de sol, 2 = inferior / clave de fá).
  final int staff;

  // Voz dentro da pauta.
  final int voice;

  // Início absoluto em semínimas desde o começo da música.
  final double startBeat;

  // Duração em semínimas.
  final double durationBeats;

  // Indica pausa.
  final bool isRest;

  // Nota secundária de um acorde (começa junto com a anterior).
  final bool isChordMember;

  // Altura: nome da nota (C, D, E, F, G, A, B), alteração e oitava.
  final String step;
  final int alter;
  final int octave;

  // Figura: whole, half, quarter, eighth, 16th, 32nd.
  final String type;

  // Quantidade de pontos de aumento.
  final int dots;

  // Acidente a ser desenhado (sharp, flat, natural...) ou null.
  final String? accidental;

  // Ligaduras de prolongamento.
  final bool tieStart;
  final bool tieStop;

  // Barras de colcheia por nível (1 = colcheia, 2 = semicolcheia):
  // begin, continue, end, forward hook, backward hook.
  final Map<int, String> beams;

  // Direção da haste informada no arquivo (up/down) ou null.
  final String? stem;

  const ScoreNote({
    required this.id,
    required this.measureIndex,
    required this.staff,
    required this.voice,
    required this.startBeat,
    required this.durationBeats,
    required this.isRest,
    required this.isChordMember,
    this.step = 'C',
    this.alter = 0,
    this.octave = 4,
    this.type = 'quarter',
    this.dots = 0,
    this.accidental,
    this.tieStart = false,
    this.tieStop = false,
    this.beams = const {},
    this.stem,
  });

  double get endBeat => startBeat + durationBeats;

  // Número MIDI (60 = Dó central).
  int get midi => (octave + 1) * 12 + stepSemitone(step) + alter;

  // Posição diatônica (C0 = 0, D0 = 1, ...), usada para desenhar na pauta.
  int get diatonic => octave * 7 + stepIndex(step);

  static int stepIndex(String step) => const {
        'C': 0,
        'D': 1,
        'E': 2,
        'F': 3,
        'G': 4,
        'A': 5,
        'B': 6,
      }[step] ??
      0;

  static int stepSemitone(String step) => const {
        'C': 0,
        'D': 2,
        'E': 4,
        'F': 5,
        'G': 7,
        'A': 9,
        'B': 11,
      }[step] ??
      0;
}

// Compasso da partitura.
class ScoreMeasure {
  final int index;

  // Número impresso no arquivo.
  final String number;

  // Início absoluto em semínimas.
  final double startBeat;

  // Duração real do compasso (anacruse pode ser menor).
  final double durationBeats;

  // Fórmula de compasso vigente.
  final int beats;
  final int beatType;

  // Armadura de clave vigente (quintas: + sustenidos, - bemóis).
  final int fifths;

  // Indica mudança de fórmula/armadura neste compasso.
  final bool showTime;
  final bool showKey;

  // Claves por pauta (G, F, C).
  final Map<int, String> clefs;

  // Notas do compasso (todas as pautas).
  final List<ScoreNote> notes;

  const ScoreMeasure({
    required this.index,
    required this.number,
    required this.startBeat,
    required this.durationBeats,
    required this.beats,
    required this.beatType,
    required this.fifths,
    required this.showTime,
    required this.showKey,
    required this.clefs,
    required this.notes,
  });

  double get endBeat => startBeat + durationBeats;
}

// Partitura completa.
class MusicalScore {
  final String title;
  final String composer;

  // Quantidade de pautas (1 ou 2 para piano).
  final int staves;

  // Andamento indicado no arquivo (semínimas por minuto), se houver.
  final int? tempo;

  final List<ScoreMeasure> measures;

  const MusicalScore({
    required this.title,
    required this.composer,
    required this.staves,
    required this.tempo,
    required this.measures,
  });

  // Todas as notas, em ordem de leitura.
  List<ScoreNote> get notes => [
        for (final measure in measures) ...measure.notes,
      ];

  double get totalBeats => measures.isEmpty ? 0 : measures.last.endBeat;

  // Fórmula de compasso inicial.
  int get beatsPerBar => measures.isEmpty ? 4 : measures.first.beats;
  int get beatType => measures.isEmpty ? 4 : measures.first.beatType;

  // Duração de um compasso inteiro em semínimas.
  double get barBeats => beatsPerBar * 4 / beatType;
}
