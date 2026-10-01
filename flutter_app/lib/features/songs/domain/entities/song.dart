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

  // Arquivos candidatos da partitura, em ordem de preferência.
  //
  // Se o documento do Firestore informa `arquivoPartitura`, ele é usado.
  // Caso contrário, procura um arquivo com o mesmo nome do MIDI exportado
  // diretamente em MusicXML (.musicxml), depois .xml e .mxl (compactado).
  List<String> get partituraCandidates {
    if (arquivoPartitura.isNotEmpty) return [arquivoPartitura];
    final dot = arquivoMidi.lastIndexOf('.');
    final base = dot > 0 ? arquivoMidi.substring(0, dot) : arquivoMidi;
    return ['$base.musicxml', '$base.xml', '$base.mxl'];
  }

  // Arquivo principal da partitura.
  String get partitura => partituraCandidates.first;
}
