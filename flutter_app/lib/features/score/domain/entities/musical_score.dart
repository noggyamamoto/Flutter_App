// Representação simbólica de uma partitura carregada de um arquivo MusicXML.
//
// Todas as posições e durações são medidas em semínimas (tempos de 1/4),
// independentemente das "divisions" usadas no arquivo.

// Clave de uma pauta: sinal (G, F, C, percussion), linha em que o sinal
// é desenhado (1 = linha inferior) e transposição de oitava (clave de
// sol 8vb = -1).
class Clef {
  final String sign;
  final int line;
  final int octaveChange;

  const Clef(this.sign, this.line, {this.octaveChange = 0});

  static const treble = Clef('G', 2);
  static const bass = Clef('F', 4);

  // Clave padrão de cada pauta quando o arquivo não informa.
  static Clef defaultFor(int staff) => staff <= 1 ? treble : bass;

  // Posição diatônica (C0 = 0) da linha inferior da pauta.
  //
  // A linha em que a clave é desenhada recebe a nota de referência da
  // clave (sol 4, fá 3 ou dó 4); as demais linhas ficam a cada terça.
  int get bottomLineDiatonic {
    final reference = switch (sign) {
      'F' => 3 * 7 + 3, // F3
      'C' => 4 * 7 + 0, // C4
      'G' => 4 * 7 + 4, // G4
      _ => 4 * 7 + 6, // percussão/TAB: B4 na linha central
    };
    final clefLine = sign == 'G' || sign == 'F' || sign == 'C' ? line : 3;
    return reference - (clefLine - 1) * 2 + octaveChange * 7;
  }

  @override
  bool operator ==(Object other) =>
      other is Clef &&
      other.sign == sign &&
      other.line == line &&
      other.octaveChange == octaveChange;

  @override
  int get hashCode => Object.hash(sign, line, octaveChange);

  @override
  String toString() => '$sign$line${octaveChange == 0 ? '' : '($octaveChange)'}';
}

// Mudança de clave no meio de um compasso.
class ClefChange {
  final int staff;
  final double beat;
  final Clef clef;

  const ClefChange({required this.staff, required this.beat, required this.clef});
}

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

  // Acidente a ser desenhado (sharp, flat, natural...) ou null. Vem do
  // arquivo (<accidental>) ou é calculado pela armadura e pelos acidentes
  // anteriores do compasso.
  final String? accidental;

  // Clave vigente da pauta no momento da nota.
  final Clef clef;

  // Pausa de compasso inteiro (centralizada no compasso).
  final bool isMeasureRest;

  // Pausa com posição vertical definida no arquivo (<display-step>).
  final bool hasRestPosition;

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
    this.clef = Clef.treble,
    this.isMeasureRest = false,
    this.hasRestPosition = false,
  });

  ScoreNote withAccidental(String? value) => ScoreNote(
        id: id,
        measureIndex: measureIndex,
        staff: staff,
        voice: voice,
        startBeat: startBeat,
        durationBeats: durationBeats,
        isRest: isRest,
        isChordMember: isChordMember,
        step: step,
        alter: alter,
        octave: octave,
        type: type,
        dots: dots,
        accidental: value,
        tieStart: tieStart,
        tieStop: tieStop,
        beams: beams,
        stem: stem,
        clef: clef,
        isMeasureRest: isMeasureRest,
        hasRestPosition: hasRestPosition,
      );

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

  // Claves vigentes no início do compasso, por pauta.
  final Map<int, Clef> clefs;

  // Mudanças de clave dentro do compasso (ou no início, quando a clave
  // muda em relação ao compasso anterior).
  final List<ClefChange> clefChanges;

  // Símbolo da fórmula de compasso: null, 'common' (C) ou 'cut'.
  final String? timeSymbol;

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
    this.clefChanges = const [],
    this.timeSymbol,
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

  // Nome do instrumento (parte) exibido no início do primeiro sistema.
  final String partName;

  const MusicalScore({
    this.partName = '',
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
