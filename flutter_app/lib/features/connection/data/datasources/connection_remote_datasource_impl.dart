import 'dart:async';

import '../../domain/entities/device_event.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/simulation_note.dart';
import '../models/device_model.dart';
import '../protocol/device_protocol.dart';
import '../transport/udp_transport.dart';
import 'connection_remote_datasource.dart';

// Comunicação com o dispositivo embarcado via UDP (RNFA02: assíncrona,
// sem bloquear a interface).
class ConnectionRemoteDataSourceImpl implements ConnectionRemoteDataSource {
  // Nome enviado ao dispositivo no pareamento.
  static const appName = 'Partitura App';

  // Intervalo do heartbeat e tempo máximo sem resposta.
  static const pingInterval = Duration(seconds: 1);
  static const connectionTimeout = Duration(seconds: 4);

  final UdpTransport _transport;
  final DeviceProtocol _protocol = DeviceProtocol();
  final _events = StreamController<DeviceEvent>.broadcast();

  StreamSubscription<UdpDatagram>? _subscription;
  DeviceModel? _device;
  Timer? _heartbeat;
  DateTime _lastPong = DateTime.now();
  bool _sessionConfirmed = false;

  // Identificador da execução atual (1..255), ecoado nas batidas.
  int _sessionId = 0;

  ConnectionRemoteDataSourceImpl({UdpTransport? transport})
      : _transport = transport ?? UdpTransport();

  @override
  bool get isSupported => _transport.isSupported;

  @override
  Stream<DeviceEvent> get events => _events.stream;

  Future<void> _ensureOpen() async {
    if (_transport.isOpen) return;
    await _transport.open();
    _subscription = _transport.datagrams.listen(_onDatagram);
  }

  // ------------------------------------------------------------------------
  // Descoberta
  // ------------------------------------------------------------------------

  @override
  Future<List<DeviceModel>> discover({
    Duration timeout = const Duration(seconds: 3),
    String? address,
  }) async {
    await _ensureOpen();

    final found = <String, DeviceModel>{};
    final subscription = _transport.datagrams.listen((datagram) {
      final packet = DeviceProtocol.decode(datagram.data);
      if (packet is AnnouncePacket) {
        found[packet.mac] = DeviceModel.fromAnnounce(
          packet,
          address: datagram.address,
          port: datagram.port,
        );
      }
    });

    // Envia a busca algumas vezes: UDP pode perder pacotes.
    final rounds = 3;
    for (var i = 0; i < rounds; i++) {
      final packet = _protocol.encodeDiscover();
      if (address != null) {
        _transport.send(packet, address, DeviceProtocol.devicePort);
      } else {
        await _transport.broadcast(packet, DeviceProtocol.devicePort);
      }
      await Future<void>.delayed(timeout ~/ rounds);
    }

    await subscription.cancel();
    return found.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  // ------------------------------------------------------------------------
  // Pareamento
  // ------------------------------------------------------------------------

  @override
  Future<void> connect(DeviceModel device) async {
    await _ensureOpen();

    final ack = Completer<bool>();
    final subscription = _transport.datagrams.listen((datagram) {
      if (datagram.address != device.address) return;
      final packet = DeviceProtocol.decode(datagram.data);
      if (packet is ConnectAckPacket && !ack.isCompleted) {
        ack.complete(packet.accepted);
      }
    });

    try {
      for (var attempt = 0; attempt < 4 && !ack.isCompleted; attempt++) {
        _transport.send(
          _protocol.encodeConnect(appName),
          device.address,
          device.port,
        );
        await Future.any([
          ack.future,
          Future<void>.delayed(const Duration(milliseconds: 600)),
        ]);
      }

      if (!ack.isCompleted) {
        throw Exception('O dispositivo não respondeu. Verifique se ele está '
            'ligado e na mesma rede Wi-Fi.');
      }
      if (!await ack.future) {
        throw Exception('O dispositivo já está em uso por outro aparelho.');
      }
    } finally {
      await subscription.cancel();
    }

    _device = device;
    _lastPong = DateTime.now();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(pingInterval, (_) {
      final device = _device;
      if (device == null) return;

      if (DateTime.now().difference(_lastPong) > connectionTimeout) {
        // Dispositivo desligado ou fora da rede.
        _heartbeat?.cancel();
        _device = null;
        _events.add(const ConnectionLostEvent());
        return;
      }
      _transport.send(_protocol.encodePing(), device.address, device.port);
    });
  }

  @override
  Future<void> disconnect() async {
    final device = _device;
    _heartbeat?.cancel();
    _device = null;
    if (device != null && _transport.isOpen) {
      // Desconexão segura: repete para o caso de perda de pacote (RU17).
      for (var i = 0; i < 2; i++) {
        _transport.send(_protocol.encodeSessionStop(), device.address, device.port);
        _transport.send(_protocol.encodeDisconnect(), device.address, device.port);
      }
    }
  }

  // ------------------------------------------------------------------------
  // Recepção
  // ------------------------------------------------------------------------

  void _onDatagram(UdpDatagram datagram) {
    final device = _device;
    if (device == null || datagram.address != device.address) return;

    final packet = DeviceProtocol.decode(datagram.data);
    if (packet == null) return;

    // Qualquer pacote do dispositivo prova que ele está ativo.
    _lastPong = DateTime.now();

    switch (packet) {
      case NoteOnPacket():
        _events.add(
          NotePlayedEvent(
            midi: packet.midi,
            frequency: packet.frequency,
            confidence: packet.confidence,
            timeMs: packet.timestampMs,
          ),
        );
      case NoteOffPacket():
        _events.add(
          NoteReleasedEvent(
            midi: packet.midi,
            durationMs: packet.durationMs,
            timeMs: packet.timestampMs,
          ),
        );
      case BeatPacket():
        // Batida de uma execução anterior (atrasada na rede): descarta, senão
        // o relógio do app seria alinhado a uma sessão que já acabou.
        if (packet.sessionId != 0 && packet.sessionId != _sessionId) return;
        _sessionConfirmed = true;
        _events.add(
          BeatEvent(
            beatInBar: packet.beatInBar,
            countIn: packet.countIn,
            barIndex: packet.barIndex,
            bpm: packet.bpm,
            timeMs: packet.timestampMs,
          ),
        );
      case PongPacket():
        _events.add(
          DeviceStatusEvent(
            rssi: packet.rssi,
            noiseFloorDb: packet.noiseFloorDb,
          ),
        );
      default:
        break;
    }
  }

  // ------------------------------------------------------------------------
  // Comandos da execução
  // ------------------------------------------------------------------------

  int _flags(SessionConfig config) =>
      (config.metronomeSound ? DeviceProtocol.flagMetronomeSound : 0) |
      (config.metronomeVisual ? DeviceProtocol.flagMetronomeVisual : 0);

  @override
  Future<void> startSession(SessionConfig config) async {
    final device = _device;
    if (device == null) throw Exception('Nenhum dispositivo conectado.');

    // O início zera o relógio do dispositivo. O reenvio (primeira batida
    // não chegou) usa o mesmo id: o firmware ignora a repetição e o relógio
    // não é zerado de novo, mantendo o app e o dispositivo sincronizados.
    _sessionConfirmed = false;
    _sessionId = _sessionId % 255 + 1;
    for (var attempt = 0; attempt < 3; attempt++) {
      _transport.send(
        _protocol.encodeSessionStart(
          bpm: config.bpm,
          beatsPerBar: config.beatsPerBar,
          countInBars: config.countInBars,
          flags: _flags(config),
          sessionId: _sessionId,
        ),
        device.address,
        device.port,
      );
      for (var wait = 0; wait < 8 && !_sessionConfirmed; wait++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (_sessionConfirmed) return;
    }
    throw Exception('O dispositivo não iniciou a execução.');
  }

  @override
  Future<void> stopSession() async {
    final device = _device;
    if (device == null) return;
    for (var i = 0; i < 2; i++) {
      _transport.send(_protocol.encodeSessionStop(), device.address, device.port);
    }
  }

  @override
  Future<void> setTempo(int bpm, {int atBeat = 0}) async {
    final device = _device;
    if (device == null) return;
    // Idempotente: repetir não altera o resultado.
    for (var i = 0; i < 2; i++) {
      _transport.send(
        _protocol.encodeSetTempo(bpm, atBeat: atBeat),
        device.address,
        device.port,
      );
    }
  }

  @override
  Future<void> configure(SessionConfig config) async {
    final device = _device;
    if (device == null) return;
    _transport.send(
      _protocol.encodeConfig(
        bpm: config.bpm,
        beatsPerBar: config.beatsPerBar,
        flags: _flags(config),
      ),
      device.address,
      device.port,
    );
  }

  @override
  void scheduleSimulation(List<SimulationNote> notes) {
    // Dispositivo real: as notas vêm do microfone.
  }

  void dispose() {
    _heartbeat?.cancel();
    _subscription?.cancel();
    _transport.close();
    _events.close();
  }
}
