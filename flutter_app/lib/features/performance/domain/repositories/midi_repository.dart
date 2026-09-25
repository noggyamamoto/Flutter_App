abstract class MidiRepository {
  Future<List<int>> getMidiFile(String path);
}