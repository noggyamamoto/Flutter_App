import '../../domain/repositories/midi_repository.dart';
import '../datasources/midi_local_datasource.dart';

class MidiRepositoryImpl implements MidiRepository {
  final MidiLocalDataSource dataSource;

  MidiRepositoryImpl(this.dataSource);

  @override
  Future<List<int>> getMidiFile(String path) {
    return dataSource.getMidiFile(path);
  }
}