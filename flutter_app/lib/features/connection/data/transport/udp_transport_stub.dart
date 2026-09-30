import 'dart:async';
import 'dart:typed_data';

import 'udp_transport.dart';

// Implementação para a web: UDP não está disponível no navegador.
class PlatformUdpTransport implements UdpTransport {
  @override
  bool get isSupported => false;

  @override
  bool get isOpen => false;

  @override
  Future<void> open() async {
    throw UnsupportedError(
      'A conexão com o dispositivo não está disponível no navegador. '
      'Use o aplicativo no celular ou no computador, ou o modo demonstração.',
    );
  }

  @override
  void send(Uint8List data, String address, int port) {}

  @override
  Future<void> broadcast(Uint8List data, int port) async {}

  @override
  Stream<UdpDatagram> get datagrams => const Stream.empty();

  @override
  void close() {}
}
