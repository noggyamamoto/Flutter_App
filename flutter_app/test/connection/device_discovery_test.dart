// Busca automática do dispositivo (feature device_discovery):
//  - no navegador (sem broadcast) o dispositivo é encontrado pela varredura
//    das sub-redes comuns;
//  - o endereço do último pareamento é consultado primeiro na busca seguinte;
//  - o nome partitura.local (mDNS) faz parte da etapa rápida.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_app/features/connection/data/datasources/connection_remote_datasource_impl.dart';
import 'package:flutter_app/features/connection/data/protocol/device_protocol.dart';
import 'package:flutter_app/features/connection/data/transport/udp_transport.dart';
import 'package:flutter_app/features/device_discovery/data/known_devices_store.dart';
import 'package:flutter_app/features/device_discovery/domain/discovery_targets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Transporte do navegador simulado: responde ANNOUNCE somente no endereço
// em que o dispositivo está.
class _WebLikeTransport implements UdpTransport {
  final String deviceAddress;
  final probed = <String>[];
  final _incoming = StreamController<UdpDatagram>.broadcast();
  bool _open = false;

  _WebLikeTransport(this.deviceAddress);

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
  Future<List<String>> localSubnets() async => const [];

  @override
  Future<void> probe(List<String> addresses, Uint8List data, int port,
      {int concurrency = 32, Duration timeout = const Duration(milliseconds: 1200)}) async {
    for (final address in addresses) {
      probed.add(address);
      send(data, address, port);
    }
  }

  @override
  void send(Uint8List data, String address, int port) {
    if (address != deviceAddress || data[3] != DeviceProtocol.discover) return;
    final bytes = ByteData(60);
    bytes.setUint16(0, DeviceProtocol.magic, Endian.little);
    bytes.setUint8(2, DeviceProtocol.version);
    bytes.setUint8(3, DeviceProtocol.announce);
    final name = 'PartituraIoT-TEST'.codeUnits;
    for (var i = 0; i < name.length; i++) {
      bytes.setUint8(12 + i, name[i]);
    }
    bytes.setUint8(48, 0xAA);
    bytes.setInt8(55, -50);
    scheduleMicrotask(() => _incoming.add(UdpDatagram(
          data: bytes.buffer.asUint8List(),
          address: address,
          port: DeviceProtocol.devicePort,
        )));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sub-redes e endereços da busca', () {
    expect(DiscoveryTargets.prefixOf('192.168.15.7'), '192.168.15');
    expect(DiscoveryTargets.prefixOf('partitura.local'), isNull);
    expect(DiscoveryTargets.quick(['192.168.0.20']),
        ['192.168.0.20', DiscoveryTargets.mdnsHost, DiscoveryTargets.accessPointAddress]);
    final subnets = DiscoveryTargets.subnets(
      local: ['10.1.1'],
      known: ['192.168.50.3'],
      includeCommon: true,
    );
    expect(subnets.first, '10.1.1');
    expect(subnets[1], '192.168.50');
    expect(subnets, contains('192.168.0'));
    expect(subnets, isNot(contains('192.168.4')));
    expect(DiscoveryTargets.hostsOf('192.168.0'), hasLength(254));
  });

  test('navegador: encontra o dispositivo varrendo as sub-redes comuns', () async {
    final transport = _WebLikeTransport('192.168.1.37');
    final dataSource = ConnectionRemoteDataSourceImpl(transport: transport);
    addTearDown(dataSource.dispose);

    final devices = await dataSource.discover(timeout: const Duration(milliseconds: 90));
    expect(devices, hasLength(1));
    expect(devices.single.address, '192.168.1.37');
    expect(transport.probed, contains(DiscoveryTargets.mdnsHost));
  });

  test('o endereço do último pareamento é consultado primeiro', () async {
    final store = KnownDevicesStore();
    await store.remember('192.168.77.9');
    final transport = _WebLikeTransport('192.168.77.9');
    final dataSource = ConnectionRemoteDataSourceImpl(transport: transport, knownDevices: store);
    addTearDown(dataSource.dispose);

    final devices = await dataSource.discover(timeout: const Duration(milliseconds: 90));
    expect(devices.single.address, '192.168.77.9');
    expect(transport.probed.first, '192.168.77.9');
    // Achado na etapa rápida: sem varredura
    expect(transport.probed.length, lessThan(20));
  });

  test('pareamento guarda o endereço para a próxima busca', () async {
    final store = KnownDevicesStore();
    await store.remember('10.0.0.5');
    await store.remember('10.0.0.8');
    await store.remember('10.0.0.5');
    expect(await store.load(), ['10.0.0.5', '10.0.0.8']);
  });
}
