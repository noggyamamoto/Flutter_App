// Preferências do usuário para a execução (RFA03).
class PerformanceSettings {
  // Melodia de fundo / música guia (RU04).
  final bool guideAudio;

  // Clique sonoro do metrônomo (RU05 / RFE02).
  final bool metronomeSound;

  // Metrônomo visual no dispositivo e na tela (RU06 / RFE03).
  final bool metronomeVisual;

  // Reduz o BPM automaticamente após uma frase instável (RU12).
  // Desligado: o app apenas sugere a redução (RFA09).
  final bool autoTempo;

  // Compassos por frase (trechos curtos – RFA04 / RFA07).
  final int measuresPerPhrase;

  // Ampliação dos símbolos da partitura (RU08).
  final double zoom;

  const PerformanceSettings({
    this.guideAudio = false,
    this.metronomeSound = true,
    this.metronomeVisual = true,
    this.autoTempo = false,
    this.measuresPerPhrase = 4,
    this.zoom = 1.2,
  });

  PerformanceSettings copyWith({
    bool? guideAudio,
    bool? metronomeSound,
    bool? metronomeVisual,
    bool? autoTempo,
    int? measuresPerPhrase,
    double? zoom,
  }) {
    return PerformanceSettings(
      guideAudio: guideAudio ?? this.guideAudio,
      metronomeSound: metronomeSound ?? this.metronomeSound,
      metronomeVisual: metronomeVisual ?? this.metronomeVisual,
      autoTempo: autoTempo ?? this.autoTempo,
      measuresPerPhrase: measuresPerPhrase ?? this.measuresPerPhrase,
      zoom: zoom ?? this.zoom,
    );
  }

  Map<String, Object> toMap() {
    return {
      'guideAudio': guideAudio,
      'metronomeSound': metronomeSound,
      'metronomeVisual': metronomeVisual,
      'autoTempo': autoTempo,
      'measuresPerPhrase': measuresPerPhrase,
      'zoom': zoom,
    };
  }
}
