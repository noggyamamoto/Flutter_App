import 'dart:convert';
import 'dart:typed_data';

// Protocolo UDP binário entre o app e o dispositivo embarcado.
//
// Espelho do arquivo MicroDetection/src/protocol.h do repositório
// firmware_I2S. Todos os pacotes começam com um cabeçalho de 12 bytes
// em little-endian:
//
//   uint16 magic  | uint8 version | uint8 type | uint32 sequence | uint32 timestamp_ms
class DeviceProtocol {
  static const int magic = 0x5443;
  static const int version = 1;
  static const int devicePort = 54322;

  // Servidor WebSocket do dispositivo (usado pelo app na web, onde não
  // existe UDP): os pacotes são os mesmos, um por mensagem binária.
  static const int webSocketPort = 80;
  static const String webSocketPath = '/ws';
  static const int headerSize = 12;
  static const int nameLength = 24;
  static const int firmwareLength = 12;

  // App -> dispositivo
  static const int discover = 0x01;
  static const int connect = 0x02;
  static const int disconnect = 0x03;
  static const int ping = 0x04;
  static const int config = 0x05;
  static const int sessionStart = 0x06;
  static const int sessionStop = 0x07;
  static const int setTempo = 0x08;

  // Dispositivo -> app
  static const int announce = 0x81;
  static const int connectAck = 0x82;
  static const int pong = 0x83;
  static const int noteOn = 0x84;
  static const int noteOff = 0x85;
  static const int pitch = 0x86;
  static const int beat = 0x87;
  static const int audioFrame = 0x88;

  // Flags de configuração
  static const int flagMetronomeSound = 1 << 0;
  static const int flagMetronomeVisual = 1 << 1;
  static const int flagStreamAudio = 1 << 2;
  static const int flagStreamPitch = 1 << 3;

  // Estados do dispositivo
  static const int stateIdle = 0;
  static const int stateConnected = 1;
  static const int stateSession = 2;

  int _sequence = 0;

  // ------------------------------------------------------------------------
  // Codificação (app -> dispositivo)
  // ------------------------------------------------------------------------

  ByteData _packet(int type, int payloadSize) {
    final data = ByteData(headerSize + payloadSize);
    data.setUint16(0, magic, Endian.little);
    data.setUint8(2, version);
    data.setUint8(3, type);
    data.setUint32(4, _sequence++ & 0xFFFFFFFF, Endian.little);
    data.setUint32(8, 0, Endian.little);
    return data;
  }

  Uint8List _bytes(ByteData data) => data.buffer.asUint8List();

  Uint8List encodeDiscover() => _bytes(_packet(discover, 0));

  Uint8List encodeConnect(String appName) {
    final data = _packet(connect, nameLength);
    final name = utf8.encode(appName);
    for (var i = 0; i < nameLength && i < name.length; i++) {
      data.setUint8(headerSize + i, name[i]);
    }
    return _bytes(data);
  }

  Uint8List encodeDisconnect() => _bytes(_packet(disconnect, 0));

  Uint8List encodePing() => _bytes(_packet(ping, 0));

  Uint8List encodeConfig({
    required int bpm,
    required int beatsPerBar,
    required int flags,
  }) {
    final data = _packet(config, 4);
    data.setUint16(12, bpm, Endian.little);
    data.setUint8(14, beatsPerBar);
    data.setUint8(15, flags);
    return _bytes(data);
  }

  Uint8List encodeSessionStart({
    required int bpm,
    required int beatsPerBar,
    required int countInBars,
    required int flags,
  }) {
    final data = _packet(sessionStart, 8);
    data.setUint16(12, bpm, Endian.little);
    data.setUint8(14, beatsPerBar);
    data.setUint8(15, countInBars);
    data.setUint8(16, flags);
    return _bytes(data);
  }

  Uint8List encodeSessionStop() => _bytes(_packet(sessionStop, 0));

  Uint8List encodeSetTempo(int bpm) {
    final data = _packet(setTempo, 4);
    data.setUint16(12, bpm, Endian.little);
    return _bytes(data);
  }

  // ------------------------------------------------------------------------
  // Decodificação (dispositivo -> app)
  // ------------------------------------------------------------------------

  // Retorna null para pacotes inválidos ou desconhecidos.
  static DevicePacket? decode(Uint8List bytes) {
    if (bytes.length < headerSize) return null;
    final data = ByteData.sublistView(bytes);
    if (data.getUint16(0, Endian.little) != magic) return null;
    if (data.getUint8(2) != version) return null;

    final type = data.getUint8(3);
    final sequence = data.getUint32(4, Endian.little);
    final timestamp = data.getUint32(8, Endian.little);

    switch (type) {
      case announce:
        if (bytes.length < 60) return null;
        return AnnouncePacket(
          sequence: sequence,
          timestampMs: timestamp,
          name: _string(bytes, 12, nameLength),
          firmware: _string(bytes, 36, firmwareLength),
          mac: bytes
              .sublist(48, 54)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase(),
          state: data.getUint8(54),
          rssi: data.getInt8(55),
          sampleRate: data.getUint16(56, Endian.little),
        );

      case connectAck:
        if (bytes.length < 16) return null;
        return ConnectAckPacket(
          sequence: sequence,
          timestampMs: timestamp,
          accepted: data.getUint8(12) == 1,
        );

      case pong:
        if (bytes.length < 24) return null;
        return PongPacket(
          sequence: sequence,
          timestampMs: timestamp,
          state: data.getUint8(12),
          rssi: data.getInt8(13),
          noiseFloorDb: data.getFloat32(16, Endian.little),
          droppedEvents: data.getUint32(20, Endian.little),
        );

      case noteOn:
        if (bytes.length < 28) return null;
        return NoteOnPacket(
          sequence: sequence,
          timestampMs: timestamp,
          midi: data.getUint8(12),
          frequency: data.getFloat32(16, Endian.little),
          levelDb: data.getFloat32(20, Endian.little),
          confidence: data.getFloat32(24, Endian.little),
        );

      case noteOff:
        if (bytes.length < 24) return null;
        return NoteOffPacket(
          sequence: sequence,
          timestampMs: timestamp,
          midi: data.getUint8(12),
          durationMs: data.getUint32(16, Endian.little),
          frequency: data.getFloat32(20, Endian.little),
        );

      case pitch:
        if (bytes.length < 24) return null;
        return PitchPacket(
          sequence: sequence,
          timestampMs: timestamp,
          frequency: data.getFloat32(12, Endian.little),
          confidence: data.getFloat32(16, Endian.little),
          levelDb: data.getFloat32(20, Endian.little),
        );

      case beat:
        if (bytes.length < 20) return null;
        return BeatPacket(
          sequence: sequence,
          timestampMs: timestamp,
          beatInBar: data.getUint8(12),
          countIn: data.getUint8(13) == 1,
          barIndex: data.getUint16(14, Endian.little),
          bpm: data.getUint16(16, Endian.little),
        );

      default:
        return null;
    }
  }

  static String _string(Uint8List bytes, int offset, int length) {
    final slice = bytes.sublist(offset, offset + length);
    final end = slice.indexOf(0);
    return utf8.decode(end < 0 ? slice : slice.sublist(0, end), allowMalformed: true);
  }
}

// Pacotes recebidos do dispositivo.
sealed class DevicePacket {
  final int sequence;
  final int timestampMs;

  const DevicePacket({required this.sequence, required this.timestampMs});
}

class AnnouncePacket extends DevicePacket {
  final String name;
  final String firmware;
  final String mac;
  final int state;
  final int rssi;
  final int sampleRate;

  const AnnouncePacket({
    required super.sequence,
    required super.timestampMs,
    required this.name,
    required this.firmware,
    required this.mac,
    required this.state,
    required this.rssi,
    required this.sampleRate,
  });
}

class ConnectAckPacket extends DevicePacket {
  final bool accepted;

  const ConnectAckPacket({
    required super.sequence,
    required super.timestampMs,
    required this.accepted,
  });
}

class PongPacket extends DevicePacket {
  final int state;
  final int rssi;
  final double noiseFloorDb;
  final int droppedEvents;

  const PongPacket({
    required super.sequence,
    required super.timestampMs,
    required this.state,
    required this.rssi,
    required this.noiseFloorDb,
    required this.droppedEvents,
  });
}

class NoteOnPacket extends DevicePacket {
  final int midi;
  final double frequency;
  final double levelDb;
  final double confidence;

  const NoteOnPacket({
    required super.sequence,
    required super.timestampMs,
    required this.midi,
    required this.frequency,
    required this.levelDb,
    required this.confidence,
  });
}

class NoteOffPacket extends DevicePacket {
  final int midi;
  final int durationMs;
  final double frequency;

  const NoteOffPacket({
    required super.sequence,
    required super.timestampMs,
    required this.midi,
    required this.durationMs,
    required this.frequency,
  });
}

class PitchPacket extends DevicePacket {
  final double frequency;
  final double confidence;
  final double levelDb;

  const PitchPacket({
    required super.sequence,
    required super.timestampMs,
    required this.frequency,
    required this.confidence,
    required this.levelDb,
  });
}

class BeatPacket extends DevicePacket {
  final int beatInBar;
  final bool countIn;
  final int barIndex;
  final int bpm;

  const BeatPacket({
    required super.sequence,
    required super.timestampMs,
    required this.beatInBar,
    required this.countIn,
    required this.barIndex,
    required this.bpm,
  });
}
