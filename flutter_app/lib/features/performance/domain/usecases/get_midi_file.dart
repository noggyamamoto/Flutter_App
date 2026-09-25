import '../repositories/midi_repository.dart';

class GetMidiFile {
  final MidiRepository repository;

  GetMidiFile(this.repository);

  Future<List<int>> call(String path) {
    return repository.getMidiFile(path);
  }
}