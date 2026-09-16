class Song {
  final String id;
  final String titulo;
  final String compositor;
  final String nivelDificuldade;
  final int bpmPadrao;
  final String arquivoMidi;

  const Song({
    required this.id, 
    required this.titulo, 
    required this.compositor, 
    required this.nivelDificuldade, 
    required this.bpmPadrao,
    required this.arquivoMidi});
}