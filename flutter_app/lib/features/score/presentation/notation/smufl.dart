// Glifos e métricas do padrão SMuFL (Standard Music Font Layout) para a
// fonte Bravura (SIL Open Font License, assets/fonts/OFL-Bravura.txt).
//
// No SMuFL, 1 em da fonte equivale a 4 espaços de pauta e a origem de cada
// glifo fica sobre a linha de referência (linha base). Por isso basta
// desenhar o glifo com tamanho de fonte = 4 × espaço e com a linha base no
// ponto desejado (linha da clave, centro da cabeça de nota etc.) para que
// tudo fique alinhado à pauta sem ajustes manuais.
//
// Todas as medidas abaixo estão em espaços de pauta (fonte: Bravura.json).
class Smufl {
  Smufl._();

  static const fontFamily = 'Bravura';

  // ---- Claves ----
  static const gClef = 0xE050;
  static const gClef8vb = 0xE052;
  static const gClef8va = 0xE053;
  static const cClef = 0xE05C;
  static const fClef = 0xE062;
  static const fClef8vb = 0xE064;
  static const unpitchedClef = 0xE069;
  static const gClefChange = 0xE07A;
  static const cClefChange = 0xE07B;
  static const fClefChange = 0xE07C;

  // ---- Fórmula de compasso ----
  static const timeSig0 = 0xE080;
  static const timeSigCommon = 0xE08A;
  static const timeSigCutCommon = 0xE08B;

  // ---- Cabeças de nota ----
  static const noteheadDoubleWhole = 0xE0A0;
  static const noteheadWhole = 0xE0A2;
  static const noteheadHalf = 0xE0A3;
  static const noteheadBlack = 0xE0A4;

  // ---- Acidentes ----
  static const accidentalFlat = 0xE260;
  static const accidentalNatural = 0xE261;
  static const accidentalSharp = 0xE262;
  static const accidentalDoubleSharp = 0xE263;
  static const accidentalDoubleFlat = 0xE264;

  // ---- Pausas ----
  static const restDoubleWhole = 0xE4E2;
  static const restWhole = 0xE4E3;
  static const restHalf = 0xE4E4;
  static const restQuarter = 0xE4E5;
  static const rest8th = 0xE4E6;
  static const rest16th = 0xE4E7;
  static const rest32nd = 0xE4E8;
  static const rest64th = 0xE4E9;

  // ---- Bandeirolas (colcheia, semicolcheia...) ----
  static const flag8thUp = 0xE240;
  static const flag8thDown = 0xE241;

  // ---- Outros ----
  static const brace = 0xE000;
  static const augmentationDot = 0xE1E7;
  static const metNoteQuarterUp = 0xECA5;

  // ---- Espessuras (engravingDefaults) ----
  static const staffLineThickness = 0.13;
  static const stemThickness = 0.12;
  static const beamThickness = 0.5;
  static const beamSpacing = 0.25;
  static const legerLineThickness = 0.16;
  static const legerLineExtension = 0.4;
  static const thinBarlineThickness = 0.16;
  static const thickBarlineThickness = 0.5;
  static const thinThickBarlineSeparation = 0.4;
  static const tieEndpointThickness = 0.1;
  static const tieMidpointThickness = 0.22;

  // Ponto de fixação da haste nas cabeças preta e branca
  // (stemUpSE = (1.18, 0.168), stemDownNW = (0, -0.168)).
  static const stemAnchorX = 1.18;
  static const stemAnchorY = 0.168;

  // Bandeirola: código do glifo para cada quantidade de bandeirolas.
  // A sequência no SMuFL é 8th, 16th, 32nd, 64th... (up, down).
  static int flag(int count, {required bool up}) =>
      flag8thUp + (count - 1) * 2 + (up ? 0 : 1);

  // Caixas delimitadoras: (x mínimo, y mínimo, x máximo, y máximo) com y
  // para cima, como no SMuFL.
  static const Map<int, List<double>> bbox = {
    gClef: [0.0, -2.632, 2.684, 4.392],
    gClef8vb: [0.0, -3.512, 2.684, 4.392],
    gClef8va: [0.0, -2.632, 2.684, 5.28],
    cClef: [0.0, -2.024, 2.796, 2.024],
    fClef: [-0.02, -2.54, 2.736, 1.048],
    fClef8vb: [-0.02, -2.976, 2.736, 1.048],
    unpitchedClef: [0.0, -1.0, 1.528, 1.0],
    gClefChange: [0.0, -1.82, 1.76, 2.828],
    cClefChange: [0.0, -1.328, 2.024, 1.328],
    fClefChange: [-0.06, -1.656, 1.852, 0.68],
    noteheadDoubleWhole: [0.0, -0.62, 2.396, 0.62],
    noteheadWhole: [0.0, -0.5, 1.688, 0.5],
    noteheadHalf: [0.0, -0.5, 1.18, 0.5],
    noteheadBlack: [0.0, -0.5, 1.18, 0.5],
    accidentalFlat: [0.0, -0.7, 0.904, 1.756],
    accidentalNatural: [0.0, -1.34, 0.672, 1.364],
    accidentalSharp: [0.0, -1.392, 0.996, 1.4],
    accidentalDoubleSharp: [0.0, -0.5, 0.988, 0.508],
    accidentalDoubleFlat: [0.0, -0.7, 1.644, 1.748],
    restDoubleWhole: [0.0, 0.0, 0.5, 1.0],
    restWhole: [0.0, -0.54, 1.128, 0.036],
    restHalf: [0.0, -0.008, 1.128, 0.568],
    restQuarter: [0.004, -1.5, 1.08, 1.492],
    rest8th: [0.0, -1.004, 0.988, 0.696],
    rest16th: [0.0, -2.0, 1.28, 0.716],
    rest32nd: [0.0, -2.0, 1.452, 1.704],
    rest64th: [0.0, -3.012, 1.692, 1.72],
    flag8thUp: [0.0, -3.24, 1.056, 0.036],
    flag8thDown: [0.0, -0.056, 1.224, 3.232],
    0xE242: [0.0, -3.252, 1.116, 0.008],
    0xE243: [0.0, -0.036, 1.164, 3.248],
    0xE244: [0.0, -3.248, 1.044, 0.596],
    0xE245: [0.0, -0.688, 1.092, 3.248],
    0xE246: [0.0, -3.248, 1.044, 1.388],
    0xE247: [0.0, -1.504, 1.092, 3.248],
    brace: [0.0, -0.003, 0.277, 4.002],
    augmentationDot: [0.0, -0.2, 0.4, 0.2],
    metNoteQuarterUp: [0.0, -0.564, 1.328, 2.752],
    timeSigCommon: [0.02, -0.996, 1.696, 1.004],
    timeSigCutCommon: [0.0, -1.436, 1.672, 1.444],
  };

  // Largura de um glifo (espaços).
  static double width(int glyph) {
    if (glyph >= timeSig0 && glyph <= timeSig0 + 9) return glyph == timeSig0 + 1 ? 1.34 : 1.78;
    final box = bbox[glyph];
    return box == null ? 1.0 : box[2] - box[0];
  }

  // Extensão acima (positivo) e abaixo (negativo) da origem (espaços).
  static double top(int glyph) => bbox[glyph]?[3] ?? 1.0;
  static double bottom(int glyph) => bbox[glyph]?[1] ?? -1.0;

  // Texto (um caractere) correspondente ao código.
  static String char(int glyph) => String.fromCharCode(glyph);
}
