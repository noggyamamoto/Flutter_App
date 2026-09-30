class Song {
  final String id;
  final String titulo;
  final String compositor;
  final String nivelDificuldade;
  final int bpmPadrao;
  final String arquivoMidi;

  // Arquivo MusicXML da partitura (assets/partituras).
  final String arquivoPartitura;

  const Song({
    required this.id, 
    required this.titulo, 
    required this.compositor, 
    required this.nivelDificuldade, 
    required this.bpmPadrao,
    required this.arquivoMidi,
    this.arquivoPartitura = ''});

  // Nome do arquivo da partitura. Documentos antigos do Firestore possuem
  // apenas o MIDI: nesse caso usa o mesmo nome com extensão .xml.
  String get partitura {
    if (arquivoPartitura.isNotEmpty) return arquivoPartitura;
    final dot = arquivoMidi.lastIndexOf('.');
    final base = dot > 0 ? arquivoMidi.substring(0, dot) : arquivoMidi;
    return '$base.xml';
  }
}
