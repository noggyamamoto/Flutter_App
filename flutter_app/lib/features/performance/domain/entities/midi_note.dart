class MidiNote {
  final int midi;
  final double inicio;
  final double duracao;
  final int velocity;

  const MidiNote({
    required this.midi,
    required this.inicio,
    required this.duracao,
    required this.velocity,
  });

  String get nome {
    const nomes = [
      'Dó',
      'Dó#',
      'Ré',
      'Ré#',
      'Mi',
      'Fá',
      'Fá#',
      'Sol',
      'Sol#',
      'Lá',
      'Lá#',
      'Si',
    ];

    return nomes[midi % 12];
  }

  int get oitava {
    return (midi ~/ 12) - 1;
  }

  String get nomeCompleto {
    return '$nome $oitava';
  }
}