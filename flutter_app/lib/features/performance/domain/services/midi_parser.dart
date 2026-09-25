import 'package:flutter_app/features/performance/domain/entities/midi_note.dart';
import 'package:flutter_app/features/performance/domain/entities/midi_score.dart';


class MidiParser {
  late List<int> _bytes;
  int _position = 0;

  MidiScore parse(
    List<int> bytes, {
    int defaultBpm = 120,
  }) {
    _bytes = bytes;
    _position = 0;

    if (_bytes.length < 14) {
      throw Exception('Arquivo MIDI inválido.');
    }

    final header = _readString(4);

    if (header != 'MThd') {
      throw Exception(
        'O arquivo não possui um cabeçalho MIDI válido.',
      );
    }

    final headerLength = _readUint32();

    if (headerLength != 6) {
      throw Exception(
        'Cabeçalho MIDI inválido.',
      );
    }

    final format = _readUint16();
    final trackCount = _readUint16();
    final ticksPerQuarter = _readUint16();

    if (format != 0 && format != 1) {
      throw Exception(
        'Formato MIDI não suportado: $format',
      );
    }

    final notes = <MidiNote>[];

    for (int track = 0; track < trackCount; track++) {
      if (_position + 8 > _bytes.length) {
        break;
      }

      final chunkType = _readString(4);

      if (chunkType != 'MTrk') {
        throw Exception(
          'Trilha MIDI inválida.',
        );
      }

      final trackLength = _readUint32();

      final trackEnd =
          _position + trackLength;

      if (trackEnd > _bytes.length) {
        throw Exception(
          'Trilha MIDI incompleta.',
        );
      }

      _parseTrack(
        trackEnd,
        ticksPerQuarter,
        notes,
      );

      _position = trackEnd;
    }

    notes.sort(
      (a, b) => a.inicio.compareTo(b.inicio),
    );

    return MidiScore(
      ticksPerQuarter: ticksPerQuarter,
      bpm: defaultBpm,
      notes: notes,
    );
  }

  void _parseTrack(
    int trackEnd,
    int ticksPerQuarter,
    List<MidiNote> notes,
  ) {
    int currentTick = 0;

    int? runningStatus;

    final activeNotes =
        <String, _ActiveMidiNote>{};

    while (_position < trackEnd) {
      final deltaTime =
          _readVariableLength();

      currentTick += deltaTime;

      if (_position >= trackEnd) {
        break;
      }

      int status = _bytes[_position];

      if (status < 0x80) {
        if (runningStatus == null) {
          throw Exception(
            'Running status inválido no MIDI.',
          );
        }

        status = runningStatus;
      } else {
        _position++;
        runningStatus = status;
      }

      // Evento Meta
      if (status == 0xFF) {
        if (_position >= trackEnd) {
          break;
        }

        final metaType = _bytes[_position++];

        final length =
            _readVariableLength();

        if (metaType == 0x2F) {
          _position += length;
          break;
        }

        _position += length;

        continue;
      }

      // SysEx
      if (status == 0xF0 ||
          status == 0xF7) {
        final length =
            _readVariableLength();

        _position += length;

        continue;
      }

      final messageType =
          status & 0xF0;

      final channel =
          status & 0x0F;

      // Note Off
      if (messageType == 0x80) {
        final noteNumber =
            _bytes[_position++];

        _position++; // velocity

        _finishNote(
          channel: channel,
          noteNumber: noteNumber,
          currentTick: currentTick,
          ticksPerQuarter: ticksPerQuarter,
          activeNotes: activeNotes,
          notes: notes,
        );

        continue;
      }

      // Note On
      if (messageType == 0x90) {
        final noteNumber =
            _bytes[_position++];

        final velocity =
            _bytes[_position++];

        if (velocity == 0) {
          _finishNote(
            channel: channel,
            noteNumber: noteNumber,
            currentTick: currentTick,
            ticksPerQuarter:
                ticksPerQuarter,
            activeNotes: activeNotes,
            notes: notes,
          );
        } else {
          final key =
              '$channel-$noteNumber';

          activeNotes[key] =
              _ActiveMidiNote(
            midi: noteNumber,
            startTick: currentTick,
            velocity: velocity,
          );
        }

        continue;
      }

      // Polyphonic Key Pressure
      if (messageType == 0xA0) {
        _position += 2;
        continue;
      }

      // Control Change
      if (messageType == 0xB0) {
        _position += 2;
        continue;
      }

      // Program Change
      if (messageType == 0xC0) {
        _position += 1;
        continue;
      }

      // Channel Pressure
      if (messageType == 0xD0) {
        _position += 1;
        continue;
      }

      // Pitch Bend
      if (messageType == 0xE0) {
        _position += 2;
        continue;
      }

      throw Exception(
        'Evento MIDI não suportado: '
        '0x${status.toRadixString(16)}',
      );
    }

    // Finaliza notas que permaneceram abertas.
    for (final active
        in activeNotes.values) {
      final durationTicks =
          currentTick - active.startTick;

      if (durationTicks > 0) {
        notes.add(
          MidiNote(
            midi: active.midi,
            inicio: active.startTick /
                ticksPerQuarter,
            duracao: durationTicks /
                ticksPerQuarter,
            velocity: active.velocity,
          ),
        );
      }
    }
  }

  void _finishNote({
    required int channel,
    required int noteNumber,
    required int currentTick,
    required int ticksPerQuarter,
    required Map<String, _ActiveMidiNote>
        activeNotes,
    required List<MidiNote> notes,
  }) {
    final key =
        '$channel-$noteNumber';

    final active =
        activeNotes.remove(key);

    if (active == null) {
      return;
    }

    final durationTicks =
        currentTick - active.startTick;

    if (durationTicks <= 0) {
      return;
    }

    notes.add(
      MidiNote(
        midi: active.midi,
        inicio:
            active.startTick /
                ticksPerQuarter,
        duracao:
            durationTicks /
                ticksPerQuarter,
        velocity: active.velocity,
      ),
    );
  }

  int _readUint16() {
    if (_position + 2 > _bytes.length) {
      throw Exception(
        'Fim inesperado do arquivo MIDI.',
      );
    }

    final value =
        (_bytes[_position] << 8) |
        _bytes[_position + 1];

    _position += 2;

    return value;
  }

  int _readUint32() {
    if (_position + 4 > _bytes.length) {
      throw Exception(
        'Fim inesperado do arquivo MIDI.',
      );
    }

    final value =
        (_bytes[_position] << 24) |
        (_bytes[_position + 1] << 16) |
        (_bytes[_position + 2] << 8) |
        _bytes[_position + 3];

    _position += 4;

    return value;
  }

  int _readVariableLength() {
    int value = 0;

    for (int i = 0; i < 4; i++) {
      if (_position >= _bytes.length) {
        throw Exception(
          'Valor variável MIDI incompleto.',
        );
      }

      final byte = _bytes[_position++];

      value = (value << 7) |
          (byte & 0x7F);

      if ((byte & 0x80) == 0) {
        return value;
      }
    }

    throw Exception(
      'Valor variável MIDI inválido.',
    );
  }

  String _readString(int length) {
    if (_position + length >
        _bytes.length) {
      throw Exception(
        'Fim inesperado do arquivo MIDI.',
      );
    }

    final result = _bytes
        .sublist(
          _position,
          _position + length,
        )
        .map(String.fromCharCode)
        .join();

    _position += length;

    return result;
  }
}

class _ActiveMidiNote {
  final int midi;
  final int startTick;
  final int velocity;

  const _ActiveMidiNote({
    required this.midi,
    required this.startTick,
    required this.velocity,
  });
}