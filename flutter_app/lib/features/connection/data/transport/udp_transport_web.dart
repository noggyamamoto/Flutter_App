import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/device_protocol.dart';
import 'udp_transport.dart';

// Implementação para a web: um WebSocket por dispositivo (ws://IP/ws).
//
// O protocolo é o mesmo do UDP (protocol.h do firmware): cada mensagem
// binária carrega um pacote. Mensagens enviadas antes de a conexão abrir
// ficam em fila.
class PlatformUdpTransport implements UdpTransport {
  final _controller = StreamController<UdpDatagram>.broadcast();
  final Map<String, _Link> _links = {};
  bool _open = false;

  @override
  bool get isSupported => true;

  @override
  bool get supportsBroadcast => false;

  @override
  bool get isOpen => _open;

  @override
  Future<void> open() async {
    _open = true;
  }

  _Link _linkTo(String address) {
    final existing = _links[address];
    if (existing != null && !existing.closed) return existing;

    final uri = Uri(
      scheme: 'ws',
      host: address,
      port: DeviceProtocol.webSocketPort,
      path: DeviceProtocol.webSocketPath,
    );
    final link = _Link(WebSocketChannel.connect(uri));
    _links[address] = link;

    link.channel.ready.then((_) {
      link.ready = true;
      for (final data in link.pending) {
        link.channel.sink.add(data);
      }
      link.pending.clear();
    }, onError: (Object _) {
      link.closed = true;
    });

    link.channel.stream.listen(
      (message) {
        final data = message is Uint8List
            ? message
            : (message is List<int> ? Uint8List.fromList(message) : null);
        if (data == null) return;
        _controller.add(UdpDatagram(data: data, address: address, port: DeviceProtocol.devicePort));
      },
      onError: (_) => link.closed = true,
      onDone: () => link.closed = true,
      cancelOnError: true,
    );
    return link;
  }

  @override
  void send(Uint8List data, String address, int port) {
    if (!_open) return;
    final link = _linkTo(address);
    if (link.ready) {
      link.channel.sink.add(data);
    } else if (link.pending.length < 32) {
      link.pending.add(data);
    }
  }

  // Sem broadcast no navegador: tenta o IP padrão da rede própria do
  // dispositivo (modo AP).
  @override
  Future<void> broadcast(Uint8List data, int port) async {
    send(data, '192.168.4.1', port);
  }

  @override
  Stream<UdpDatagram> get datagrams => _controller.stream;

  @override
  void close() {
    for (final link in _links.values) {
      link.channel.sink.close();
    }
    _links.clear();
    _open = false;
  }
}

class _Link {
  final WebSocketChannel channel;
  final List<Uint8List> pending = [];
  bool ready = false;
  bool closed = false;

  _Link(this.channel);
}
