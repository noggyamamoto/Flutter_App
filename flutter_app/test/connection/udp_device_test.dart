// Teste de integração do protocolo UDP com o "dispositivo falso" em C,
// compilado a partir do protocol.h do firmware (repositório firmware_I2S):
//
//   make -C MicroDetection/test/host fake_device
//   FAKE_DEVICE=/caminho/para/fake_device flutter test test/connection
//
// Sem a variável FAKE_DEVICE o teste é ignorado.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/features/connection/data/datasources/connection_remote_datasource_impl.dart';
import 'package:flutter_app/features/connection/domain/entities/device_event.dart';
import 'package:flutter_app/features/connection/domain/entities/session_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binary = Platform.environment['FAKE_DEVICE'];

  test('descoberta, pareamento, sessão e notas com o firmware (protocol.h)', () async {
    final process = await Process.start(binary!, []);
    final output = <String>[];
    process.stdout.transform(utf8.decoder).listen(output.add);
    addTearDown(process.kill);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final dataSource = ConnectionRemoteDataSourceImpl();
    addTearDown(dataSource.dispose);

    // Descoberta pelo IP (unicast)
    final devices = await dataSource.discover(
      timeout: const Duration(milliseconds: 600),
      address: '127.0.0.1',
    );
    expect(devices, hasLength(1));
    final device = devices.single;
    expect(device.name, 'PartituraIoT-TEST');
    expect(device.id, '24:6F:28:AA:BB:CC');
    expect(device.firmware, '1.0.0');
    expect(device.rssi, -48);

    // Pareamento
    await dataSource.connect(device);

    final events = <DeviceEvent>[];
    final sub = dataSource.events.listen(events.add);
    addTearDown(sub.cancel);

    // Sessão: 240 BPM, 4 tempos, 1 compasso de contagem
    await dataSource.startSession(
      const SessionConfig(bpm: 240, beatsPerBar: 4, countInBars: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 3400));

    final beats = events.whereType<BeatEvent>().toList();
    final notes = events.whereType<NotePlayedEvent>().toList();
    final releases = events.whereType<NoteReleasedEvent>().toList();
    final status = events.whereType<DeviceStatusEvent>().toList();

    expect(beats.first.barIndex, 0);
    expect(beats.first.countIn, isTrue);
    expect(beats.where((b) => b.countIn), hasLength(4));
    expect(beats.first.bpm, 240);

    expect(notes.map((n) => n.midi).toList(), [60, 62, 64, 65, 67, 69, 71, 72]);
    expect(notes.first.timeMs, 1000); // após 1 compasso de 4 tempos a 240 BPM
    expect(notes[1].timeMs, 1250);
    expect(notes.first.confidence, closeTo(0.95, 1e-6));
    expect(releases.first.durationMs, 210);

    // Heartbeat
    expect(status, isNotEmpty);
    expect(status.first.noiseFloorDb, closeTo(-71.5, 1e-6));

    await dataSource.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final log = output.join();
    expect(log, contains('CONNECT de Partitura App'));
    expect(log, contains('SESSION_START bpm=240 beats=4 count_in=1 flags=0x03'));
    expect(log, contains('DISCONNECT'));
  }, skip: binary == null ? 'defina FAKE_DEVICE para executar' : false);
}
