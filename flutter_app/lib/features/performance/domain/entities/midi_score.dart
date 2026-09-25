import 'package:flutter_app/features/performance/domain/entities/midi_note.dart';

class MidiScore {
  final int ticksPerQuarter;
  final int bpm;
  final List<MidiNote> notes;

  const MidiScore({
    required this.ticksPerQuarter,
    required this.bpm,
    required this.notes,
  });

  double get duracaoTotal {
    if (notes.isEmpty) {
      return 0;
    }

    return notes
        .map(
          (note) => note.inicio + note.duracao,
        )
        .reduce(
          (a, b) => a > b ? a : b,
        );
  }
}