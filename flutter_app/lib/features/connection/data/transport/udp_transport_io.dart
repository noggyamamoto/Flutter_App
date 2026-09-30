import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'udp_transport.dart';

// Implementação com dart:io (Android, iOS, desktop).
class PlatformUdpTransport implements UdpTransport {
  RawDatagramSocket? _socket;
  final _controller = StreamController<UdpDatagram>.broadcast();

  @override
  bool get isSupported => true;

  @override
  bool get isOpen => _socket != null;

  @override
  Future<void> open() async {
    if (_socket != null) return;
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        _controller.add(
          UdpDatagram(
            data: datagram!.data,
            address: datagram.address.address,
            port: datagram.port,
          ),
        );
      }
    });
    _socket = socket;
  }

  @override
  void send(Uint8List data, String address, int port) {
    final socket = _socket;
    if (socket == null) return;
    final target = InternetAddress.tryParse(address);
    if (target == null) return;
    socket.send(data, target, port);
  }

  @override
  Future<void> broadcast(Uint8List data, int port) async {
    final socket = _socket;
    if (socket == null) return;

    // Broadcast global + broadcast de cada sub-rede /24 das interfaces ativas
    // (alguns roteadores e sistemas bloqueiam 255.255.255.255).
    final targets = <String>{'255.255.255.255', '192.168.4.255'};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final parts = address.address.split('.');
          if (parts.length == 4) {
            targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
          }
        }
      }
    } catch (_) {
      // Sem permissão para listar interfaces: usa apenas o broadcast global.
    }

    for (final target in targets) {
      try {
        socket.send(data, InternetAddress(target), port);
      } catch (_) {
        // Interface sem rota para o endereço: ignora.
      }
    }
  }

  @override
  Stream<UdpDatagram> get datagrams => _controller.stream;

  @override
  void close() {
    _socket?.close();
    _socket = null;
  }
}
