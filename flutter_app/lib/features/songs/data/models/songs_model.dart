import 'package:flutter_app/features/songs/domain/entities/song.dart';

class SongsModel {
  final String id;
  final String titulo;
  final String compositor;
  final String nivelDificuldade;
  final int bpmPadrao;
  final String arquivoMidi;
  final String arquivoPartitura;

  const SongsModel({
    required this.id,
    required this.titulo,
    required this.compositor,
    required this.nivelDificuldade,
    required this.bpmPadrao,
    required this.arquivoMidi,
    this.arquivoPartitura = '',
  });

  factory SongsModel.fromMap(Map<String, dynamic> map) {
    return SongsModel(
      id: map['id'] ?? '',
      titulo: map['titulo'] ?? '',
      compositor: map['compositor'] ?? '',
      nivelDificuldade: map['nivelDificuldade'] ?? '',
      bpmPadrao: (map['bpmPadrao'] as num?)?.toInt() ?? 0,
      arquivoMidi: map['arquivoMidi'] ?? '',
      arquivoPartitura: map['arquivoPartitura'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'compositor': compositor,
      'nivelDificuldade': nivelDificuldade,
      'bpmPadrao': bpmPadrao,
      'arquivoMidi': arquivoMidi,
      'arquivoPartitura': arquivoPartitura,
    };
  }

  Song toEntity() {
    return Song(
      id: id,
      titulo: titulo,
      compositor: compositor,
      nivelDificuldade: nivelDificuldade,
      bpmPadrao: bpmPadrao,
      arquivoMidi: arquivoMidi,
      arquivoPartitura: arquivoPartitura,
    );
  }
}