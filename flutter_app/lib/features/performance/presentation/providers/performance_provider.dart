import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_app/features/history/presentation/providers/history_provider.dart';

import '../../../songs/domain/entities/song.dart';

import '../../data/datasources/midi_local_datasource.dart';
import '../../data/datasources/midi_local_datasource_impl.dart';

import '../../data/repositories/midi_repository_impl.dart';

import '../../domain/entities/midi_score.dart';
import '../../domain/entities/performance_state.dart';

import '../../domain/repositories/midi_repository.dart';

import '../../domain/services/midi_parser.dart';

import '../../domain/usecases/get_midi_file.dart';


// ---------------------------------------------------------
// MIDI DATA SOURCE
// ---------------------------------------------------------

final midiDataSourceProvider =
    Provider<MidiLocalDataSource>((ref) {

  return MidiLocalDataSourceImpl();
});


// ---------------------------------------------------------
// MIDI REPOSITORY
// ---------------------------------------------------------

final midiRepositoryProvider =
    Provider<MidiRepository>((ref) {

  final dataSource =
      ref.watch(
    midiDataSourceProvider,
  );

  return MidiRepositoryImpl(
    dataSource,
  );
});


// ---------------------------------------------------------
// GET MIDI FILE
// ---------------------------------------------------------

final getMidiFileProvider =
    Provider<GetMidiFile>((ref) {

  final repository =
      ref.watch(
    midiRepositoryProvider,
  );

  return GetMidiFile(
    repository,
  );
});


// ---------------------------------------------------------
// MIDI PARSER
// ---------------------------------------------------------

final midiParserProvider =
    Provider<MidiParser>((ref) {

  return MidiParser();
});


// ---------------------------------------------------------
// PERFORMANCE NOTIFIER
// ---------------------------------------------------------

class PerformanceNotifier
    extends Notifier<PerformanceState> {

  // Timer utilizado para contar
  // o tempo da performance.
  Timer? _timer;


  @override
  PerformanceState build() {

    // Cancela o timer quando o provider
    // deixar de ser utilizado.
    ref.onDispose(() {

      _timer?.cancel();
    });

    // Estado inicial da performance.
    return const PerformanceState(
      status:
          PerformanceStatus.initial,
    );
  }


  // -------------------------------------------------------
  // CARREGAR MÚSICA
  // -------------------------------------------------------

  Future<void> loadSong(
    Song song,
  ) async {

    // Cancela qualquer timer anterior.
    _timer?.cancel();

    // Coloca a tela em estado de carregamento.
    state =
        const PerformanceState(
      status:
          PerformanceStatus.loading,
    );

    try {

      // Recupera o caso de uso
      // responsável pelo arquivo MIDI.
      final getMidiFile =
          ref.read(
        getMidiFileProvider,
      );

      // Recupera o parser MIDI.
      final parser =
          ref.read(
        midiParserProvider,
      );

      // Monta o caminho do arquivo MIDI.
      final midiPath =
          'assets/midi/${song.arquivoMidi}';

      // Carrega o arquivo MIDI.
      final bytes =
          await getMidiFile(
        midiPath,
      );

      // Converte o arquivo MIDI
      // para a entidade MidiScore.
      final MidiScore score =
          parser.parse(
        bytes,
        defaultBpm:
            song.bpmPadrao,
      );

      // Informa que a música está
      // pronta para ser executada.
      state =
          PerformanceState(
        status:
            PerformanceStatus.ready,

        score:
            score,
      );

    } catch (e) {

      // Caso ocorra algum erro,
      // informa o erro para a interface.
      state =
          PerformanceState(
        status:
            PerformanceStatus.error,

        errorMessage:
            e.toString(),
      );
    }
  }


  // -------------------------------------------------------
  // INICIAR CONTAGEM REGRESSIVA
  // -------------------------------------------------------

  void startCountdown() {

    state =
        state.copyWith(
      status:
          PerformanceStatus.countdown,
    );
  }


  // -------------------------------------------------------
  // INICIAR PERFORMANCE
  // -------------------------------------------------------

  void startPerformance() {

    state =
        state.copyWith(

      status:
          PerformanceStatus.running,

      elapsed:
          Duration.zero,
    );

    // Inicia o contador de tempo.
    _startTimer();
  }


  // -------------------------------------------------------
  // TIMER
  // -------------------------------------------------------

  void _startTimer() {

    // Cancela um timer anterior.
    _timer?.cancel();

    // Cria um timer que executa
    // a cada segundo.
    _timer = Timer.periodic(

      const Duration(
        seconds: 1,
      ),

      (_) {

        // Se a performance não estiver
        // rodando, não atualiza o tempo.
        if (state.status !=
            PerformanceStatus.running) {

          return;
        }

        // Adiciona um segundo ao tempo.
        state =
            state.copyWith(

          elapsed:
              state.elapsed +
                  const Duration(
                    seconds: 1,
                  ),
        );
      },
    );
  }


  // -------------------------------------------------------
  // ATUALIZAR PRECISÃO
  // -------------------------------------------------------

  void updatePrecision(
    double precision,
  ) {

    state =
        state.copyWith(

      precision:
          precision,
    );
  }


  // -------------------------------------------------------
  // ATUALIZAR NOTAS EXECUTADAS
  // -------------------------------------------------------

  void updateNotesPlayed(
    int notesPlayed,
  ) {

    state =
        state.copyWith(

      notesPlayed:
          notesPlayed,
    );
  }


  // -------------------------------------------------------
  // FINALIZAR PERFORMANCE
  // -------------------------------------------------------

  void finishPerformance() {

    // Para o contador.
    _timer?.cancel();

    // Altera o status para finalizado.
    state =
        state.copyWith(

      status:
          PerformanceStatus.finished,
    );
  }


  // -------------------------------------------------------
  // SALVAR PERFORMANCE
  // -------------------------------------------------------

  Future<String> savePerformance({

    required String userId,

    required String songId,

    required int bpmInicial,

    required double pontuacaoFinal,

  }) async {

    // Recupera o caso de uso responsável
    // por salvar a execução.
    final savePerformance =
        ref.read(
      savePerformanceProvider,
    );

    // Executa o salvamento.
    return savePerformance(

      userId:
          userId,

      songId:
          songId,

      bpmInicial:
          bpmInicial,

      pontuacaoFinal:
          pontuacaoFinal,

      status:
          'concluida',
    );
  }


  // -------------------------------------------------------
  // RESETAR
  // -------------------------------------------------------

  void reset() {

    // Cancela o timer.
    _timer?.cancel();

    // Volta ao estado inicial.
    state =
        const PerformanceState(
      status:
          PerformanceStatus.initial,
    );
  }
}


// ---------------------------------------------------------
// PERFORMANCE PROVIDER
// ---------------------------------------------------------

final performanceProvider =
    NotifierProvider<
        PerformanceNotifier,
        PerformanceState>(
  PerformanceNotifier.new,
);