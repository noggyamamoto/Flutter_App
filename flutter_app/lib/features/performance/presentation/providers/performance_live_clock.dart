import 'package:flutter/foundation.dart';

// Valores da execução que mudam a cada quadro: cursor da partitura,
// metrônomo visual, contagem de entrada e tempo decorrido.
//
// Ficam fora do PerformanceState de propósito: cada mudança de estado
// reconstrói a tela inteira, e estes valores mudam até 60 vezes por segundo.
// Aqui, somente o widget que mostra cada valor é redesenhado (cursor:
// apenas a camada do cursor; metrônomo: apenas os pontos do compasso).
//
// Os valores vêm do relógio da sessão (alinhado às batidas do dispositivo),
// por isso o metrônomo visual não "engasga" quando os pacotes da rede
// chegam com atraso irregular.
class PerformanceLiveClock {
  // Posição do cursor (semínimas); null fora da execução.
  final ValueNotifier<double?> cursorBeat = ValueNotifier(null);

  // Batida do metrônomo desde o início da sessão (0 = primeira batida da
  // contagem de entrada); -1 fora da contagem/execução.
  final ValueNotifier<int> metronomeBeat = ValueNotifier(-1);

  // Segundos desde o início da música.
  final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);

  // Há uma contagem ou execução em andamento alimentando os valores.
  bool get isRunning => metronomeBeat.value >= 0;

  void update({
    required double? cursor,
    required int beat,
    required int elapsed,
  }) {
    cursorBeat.value = cursor;
    metronomeBeat.value = beat;
    elapsedSeconds.value = elapsed;
  }

  void clear() {
    cursorBeat.value = null;
    metronomeBeat.value = -1;
    elapsedSeconds.value = 0;
  }

  void dispose() {
    cursorBeat.dispose();
    metronomeBeat.dispose();
    elapsedSeconds.dispose();
  }
}
