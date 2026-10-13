import 'dart:typed_data';

import 'udp_transport_web.dart'
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

// Transporte de datagramas independente de plataforma.
//
// - Android, iOS, macOS, Windows e Linux: UDP com RawDatagramSocket
//   (dart:io), com descoberta por broadcast.
// - Web: o navegador não tem UDP; cada "datagrama" é uma mensagem binária
//   em um WebSocket com o dispositivo (ws://IP/ws – RNFA02). Não há
//   broadcast: a busca consulta endereço a endereço (probe), começando pelo
//   nome partitura.local (mDNS), pelos IPs já usados e pela rede própria do
//   dispositivo (192.168.4.1).
abstract class UdpTransport {
  factory UdpTransport() = platform.PlatformUdpTransport;

  bool get isSupported;

  // Descoberta por broadcast disponível (false na web).
  bool get supportsBroadcast;

  // Abre o socket em uma porta livre com broadcast habilitado.
  Future<void> open();

  bool get isOpen;

  // Envia para um endereço específico.
  void send(Uint8List data, String address, int port);

  // Envia por broadcast em todas as interfaces de rede.
  Future<void> broadcast(Uint8List data, int port);

  // Prefixos /24 das redes locais (ex.: 192.168.0). Vazio quando não é
  // possível saber (navegador).
  Future<List<String>> localSubnets();

  // Envia o mesmo pacote a vários endereços (IP ou nome, como
  // partitura.local), no máximo `concurrency` aberturas ao mesmo tempo, cada
  // uma esperando até `timeout`. Usado na busca sem broadcast.
  Future<void> probe(
    List<String> addresses,
    Uint8List data,
    int port, {
    int concurrency = 32,
    Duration timeout = const Duration(milliseconds: 1200),
  });

  Stream<UdpDatagram> get datagrams;

  void close();
}
