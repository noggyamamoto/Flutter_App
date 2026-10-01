// Teste de integração do app WEB com o dispositivo (transporte WebSocket).
//
// No navegador não existe UDP: o app conversa com o firmware por
// ws://IP/ws. Este teste roda no Chrome contra o dispositivo falso do
// firmware atrás da ponte WebSocket <-> UDP (repositório firmware_I2S):
//
//   make -C MicroDetection/test/host fake_device
//   ./MicroDetection/test/host/fake_device &
//   python3 MicroDetection/test/host/ws_bridge.py 80 &
//   flutter test --platform chrome --dart-define=WS_DEVICE=true \
//       test/connection/websocket_device_test.dart
@TestOn('browser')
library;

import 'package:flutter_app/features/connection/data/datasources/connection_remote_datasource_impl.dart';
import 'package:flutter_app/features/connection/domain/entities/device_event.dart';
import 'package:flutter_app/features/connection/domain/entities/session_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('WS_DEVICE');

void main() {
  test('app web: descoberta pelo IP, pareamento, sessão e notas via WebSocket', () async {
    final dataSource = ConnectionRemoteDataSourceImpl();
    addTearDown(dataSource.dispose);

    final devices = await dataSource.discover(
      timeout: const Duration(milliseconds: 1500),
      address: '127.0.0.1',
    );
    expect(devices, hasLength(1));
    final device = devices.single;
    expect(device.name, 'PartituraIoT-TEST');
    expect(device.firmware, '1.0.0');

    await dataSource.connect(device);

    final events = <DeviceEvent>[];
    final sub = dataSource.events.listen(events.add);
    addTearDown(sub.cancel);

    await dataSource.startSession(
      const SessionConfig(bpm: 240, beatsPerBar: 4, countInBars: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 3400));

    final beats = events.whereType<BeatEvent>().toList();
    final notes = events.whereType<NotePlayedEvent>().toList();

    expect(beats.where((b) => b.countIn), hasLength(4));
    expect(notes.map((n) => n.midi).toList(), [60, 62, 64, 65, 67, 69, 71, 72]);
    expect(notes.first.timeMs, 1000);
    expect(events.whereType<DeviceStatusEvent>(), isNotEmpty);

    await dataSource.disconnect();
  }, skip: _enabled ? false : 'defina --dart-define=WS_DEVICE=true (ver cabeçalho)');
}
