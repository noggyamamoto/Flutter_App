import 'dart:typed_data';

import 'udp_transport_stub.dart'
    if (dart.library.io) 'udp_transport_io.dart' as platform;

// Datagrama recebido.
class UdpDatagram {
  final Uint8List data;
  final String address;
  final int port;

  const UdpDatagram({
    required this.data,
    required this.address,
    required this.port,
  });
}

// Socket UDP independente de plataforma.
//
// Em Android, iOS, macOS, Windows e Linux usa RawDatagramSocket (dart:io).
// Na web não existe UDP: `isSupported` retorna false.
abstract class UdpTransport {
  factory UdpTransport() = platform.PlatformUdpTransport;

  bool get isSupported;

  // Abre o socket em uma porta livre com broadcast habilitado.
  Future<void> open();

  bool get isOpen;

  // Envia para um endereço específico.
  void send(Uint8List data, String address, int port);

  // Envia por broadcast em todas as interfaces de rede.
  Future<void> broadcast(Uint8List data, int port);

  Stream<UdpDatagram> get datagrams;

  void close();
}
