import 'dart:async';
import 'dart:math';

import '../../domain/entities/device_event.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/simulation_note.dart';
import '../models/device_model.dart';
import 'connection_remote_datasource.dart';

// Dispositivo virtual do modo demonstração.
//
// Reproduz o comportamento do firmware (metrônomo e eventos de nota) sem
// hardware, tocando as notas da partitura com pequenas imprecisões de
// tempo e alguns erros, para apresentar e testar o fluxo completo do app
// (inclusive na web, onde não há UDP).
class SimulatedDeviceDataSource implements ConnectionRemoteDataSource {
  // Probabilidades de erro do "aluno virtual".
  final double wrongNoteRate;
  final double missedNoteRate;
  final int timingJitterMs;

  final _events = StreamController<DeviceEvent>.broadcast();
  final Random _random;

  bool _connected = false;
  Timer? _ticker;
  Stopwatch? _clock;

  // Metrônomo
  int _bpm = 100;
  int? _pendingBpm;
  int _pendingAt = 0;
  int _beatsPerBar = 4;
  int _countInBars = 2;
  int _beatIndex = 0;
  double _nextBeatMs = 0;

  // Notas agendadas: (instante, evento)
  final List<_Scheduled> _queue = [];

  SimulatedDeviceDataSource({
    this.wrongNoteRate = 0.06,
    this.missedNoteRate = 0.04,
    this.timingJitterMs = 35,
    int? seed,
  }) : _random = Random(seed);

  @override
  bool get isSupported => true;

  @override
  Stream<DeviceEvent> get events => _events.stream;

  @override
  Future<List<DeviceModel>> discover({
    Duration timeout = const Duration(seconds: 1),
    String? address,
  }) async {
    return const [];
  }

  @override
  Future<void> connect(DeviceModel device) async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    await stopSession();
    _connected = false;
  }

  @override
  Future<void> startSession(SessionConfig config) async {
    if (!_connected) throw Exception('Nenhum dispositivo conectado.');
    _ticker?.cancel();
    _queue.clear();
    _bpm = config.bpm;
    _pendingBpm = null;
    _beatsPerBar = config.beatsPerBar;
    _countInBars = config.countInBars;
    _beatIndex = 0;
    _nextBeatMs = 0;
    _clock = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 5), (_) => _tick());
    _tick();
  }

  @override
  Future<void> stopSession() async {
    _ticker?.cancel();
    _ticker = null;
    _clock?.stop();
    _queue.clear();
  }

  @override
  Future<void> setTempo(int bpm, {int atBeat = 0}) async {
    // Mesma regra do firmware: vale a partir da batida `atBeat`
    // (ou da próxima, se ela já passou).
    _pendingBpm = bpm;
    _pendingAt = atBeat;
  }

  @override
  Future<void> configure(SessionConfig config) async {}

  @override
  void scheduleSimulation(List<SimulationNote> notes) {
    final now = _clock?.elapsedMilliseconds ?? 0;
    _queue.removeWhere((s) => s.timeMs > now);

    for (final note in notes) {
      if (note.onsetMs < now) continue;
      if (_random.nextDouble() < missedNoteRate) continue;

      var midi = note.midi;
      if (_random.nextDouble() < wrongNoteRate) {
        midi += (_random.nextBool() ? 1 : -1) * (1 + _random.nextInt(2));
      }
      final jitter = (_random.nextDouble() * 2 - 1) * timingJitterMs;
      final onset = (note.onsetMs + jitter).round();
      final duration = max(60, (note.durationMs * (0.8 + _random.nextDouble() * 0.2)).round());
      final frequency = 440.0 * pow(2, (midi - 69) / 12.0);

      _queue.add(
        _Scheduled(
          onset,
          NotePlayedEvent(
            midi: midi,
            frequency: frequency.toDouble(),
            confidence: 0.9,
            timeMs: onset,
          ),
        ),
      );
      _queue.add(
        _Scheduled(
          onset + duration,
          NoteReleasedEvent(midi: midi, durationMs: duration, timeMs: onset + duration),
        ),
      );
    }
    _queue.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  }

  void _tick() {
    final clock = _clock;
    if (clock == null) return;
    final now = clock.elapsedMilliseconds;

    // Batidas do metrônomo
    while (now >= _nextBeatMs) {
      if (_pendingBpm != null && _beatIndex >= _pendingAt) {
        _bpm = _pendingBpm!;
        _pendingBpm = null;
      }
      final bar = _beatIndex ~/ _beatsPerBar;
      _events.add(
        BeatEvent(
          beatInBar: _beatIndex % _beatsPerBar,
          countIn: bar < _countInBars,
          barIndex: bar,
          bpm: _bpm,
          timeMs: _nextBeatMs.round(),
        ),
      );
      _beatIndex++;
      _nextBeatMs += 60000 / _bpm;
    }

    // Notas vencidas
    while (_queue.isNotEmpty && _queue.first.timeMs <= now) {
      _events.add(_queue.removeAt(0).event);
    }
  }
}

class _Scheduled {
  final int timeMs;
  final DeviceEvent event;

  _Scheduled(this.timeMs, this.event);
}
