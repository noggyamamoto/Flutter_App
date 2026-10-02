// Sincronismo do início da execução entre o app e o firmware:
//  - o reenvio do SESSION_START usa o mesmo session_id (o firmware ignora a
//    repetição e não zera o relógio de novo);
//  - batidas de uma execução anterior são descartadas;
//  - SET_TEMPO leva a batida exata em que o novo andamento começa.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_app/features/connection/data/datasources/connection_remote_datasource_impl.dart';
import 'package:flutter_app/features/connection/data/models/device_model.dart';
import 'package:flutter_app/features/connection/data/protocol/device_protocol.dart';
import 'package:flutter_app/features/connection/data/transport/udp_transport.dart';
import 'package:flutter_app/features/connection/domain/entities/device_event.dart';
import 'package:flutter_app/features/connection/domain/entities/session_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _device = DeviceModel(
  id: 'AA:BB',
  name: 'PartituraIoT-TEST',
  address: '10.0.0.5',
  port: DeviceProtocol.devicePort,
  firmware: '1.1.0',
  rssi: -50,
  state: DeviceProtocol.stateIdle,
);

// Transporte em memória que responde como o firmware.
class _FakeTransport implements UdpTransport {
  final sent = <Uint8List>[];
  final _incoming = StreamController<UdpDatagram>.broadcast();
  bool _open = false;

  // Quantos SESSION_START são "perdidos" (sem batida de resposta).
  int dropSessionStarts = 0;

  @override
  bool get isSupported => true;
  @override
  bool get supportsBroadcast => false;
  @override
  bool get isOpen => _open;
  @override
  Future<void> open() async => _open = true;
  @override
  Stream<UdpDatagram> get datagrams => _incoming.stream;
  @override
  Future<void> broadcast(Uint8List data, int port) async {}
  @override
  void close() => _open = false;

  @override
  void send(Uint8List data, String address, int port) {
    sent.add(data);
    final type = data[3];
    if (type == DeviceProtocol.connect) {
      deliver(_packet(DeviceProtocol.connectAck, 4)..[12] = 1);
    } else if (type == DeviceProtocol.sessionStart) {
      if (dropSessionStarts > 0) {
        dropSessionStarts--;
        return;
      }
      deliver(beat(sessionId: data[17], timeMs: 0));
    }
  }

  void deliver(Uint8List bytes) {
    scheduleMicrotask(() => _incoming.add(
          UdpDatagram(data: bytes, address: _device.address, port: _device.port),
        ));
  }

  static Uint8List _packet(int type, int payload) {
    final data = ByteData(12 + payload);
    data.setUint16(0, DeviceProtocol.magic, Endian.little);
    data.setUint8(2, DeviceProtocol.version);
    data.setUint8(3, type);
    return data.buffer.asUint8List();
  }

  static Uint8List beat({required int sessionId, required int timeMs, int bpm = 100}) {
    final bytes = _packet(DeviceProtocol.beat, 8);
    final data = ByteData.sublistView(bytes);
    data.setUint32(8, timeMs, Endian.little);
    data.setUint16(16, bpm, Endian.little);
    data.setUint8(18, sessionId);
    return bytes;
  }
}

List<Uint8List> _ofType(List<Uint8List> packets, int type) =>
    packets.where((p) => p[3] == type).toList();

void main() {
  late _FakeTransport transport;
  late ConnectionRemoteDataSourceImpl dataSource;

  setUp(() async {
    transport = _FakeTransport();
    dataSource = ConnectionRemoteDataSourceImpl(transport: transport);
    await dataSource.connect(_device);
  });

  tearDown(() => dataSource.dispose());

  test('reenvio do SESSION_START mantém o mesmo session_id', () async {
    transport.dropSessionStarts = 1;                // 1ª batida não chega
    await dataSource.startSession(const SessionConfig(bpm: 100, beatsPerBar: 4));

    final starts = _ofType(transport.sent, DeviceProtocol.sessionStart);
    expect(starts, hasLength(2));
    expect(starts[0][17], isNot(0));
    expect(starts[1][17], starts[0][17]);
  });

  test('cada execução nova tem outro session_id', () async {
    await dataSource.startSession(const SessionConfig(bpm: 100, beatsPerBar: 4));
    await dataSource.startSession(const SessionConfig(bpm: 100, beatsPerBar: 4));
    final starts = _ofType(transport.sent, DeviceProtocol.sessionStart);
    expect(starts[1][17], isNot(starts[0][17]));
  });

  test('batidas de outra execução são descartadas', () async {
    await dataSource.startSession(const SessionConfig(bpm: 100, beatsPerBar: 4));
    final current = _ofType(transport.sent, DeviceProtocol.sessionStart).last[17];

    final beats = <BeatEvent>[];
    final sub = dataSource.events.listen((e) {
      if (e is BeatEvent) beats.add(e);
    });
    transport.deliver(_FakeTransport.beat(sessionId: (current % 255) + 1, timeMs: 600));
    transport.deliver(_FakeTransport.beat(sessionId: current, timeMs: 600));
    transport.deliver(_FakeTransport.beat(sessionId: 0, timeMs: 1200));   // firmware antigo
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(beats.map((b) => b.timeMs), [600, 1200]);
  });

  test('SET_TEMPO informa a batida em que o novo BPM começa', () async {
    await dataSource.setTempo(90, atBeat: 40);
    final packet = _ofType(transport.sent, DeviceProtocol.setTempo).first;
    final data = ByteData.sublistView(packet);
    expect(data.getUint16(12, Endian.little), 90);
    expect(data.getUint16(14, Endian.little), 40);
  });
}
