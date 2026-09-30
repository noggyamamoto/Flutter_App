import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/performance_settings.dart';

// Preferências salvas localmente no aparelho.
class ConfigurationNotifier extends Notifier<PerformanceSettings> {
  static const _prefix = 'config.';

  @override
  PerformanceSettings build() {
    // Carrega as preferências salvas sem bloquear a interface.
    Future.microtask(_load);
    return const PerformanceSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const d = PerformanceSettings();
      state = PerformanceSettings(
        guideAudio: prefs.getBool('${_prefix}guideAudio') ?? d.guideAudio,
        metronomeSound: prefs.getBool('${_prefix}metronomeSound') ?? d.metronomeSound,
        metronomeVisual: prefs.getBool('${_prefix}metronomeVisual') ?? d.metronomeVisual,
        autoTempo: prefs.getBool('${_prefix}autoTempo') ?? d.autoTempo,
        measuresPerPhrase: prefs.getInt('${_prefix}measuresPerPhrase') ?? d.measuresPerPhrase,
        zoom: prefs.getDouble('${_prefix}zoom') ?? d.zoom,
      );
    } catch (_) {
      // Sem armazenamento disponível: mantém os valores padrão.
    }
  }

  Future<void> update(PerformanceSettings settings) async {
    state = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in settings.toMap().entries) {
        final key = '$_prefix${entry.key}';
        final value = entry.value;
        if (value is bool) await prefs.setBool(key, value);
        if (value is int) await prefs.setInt(key, value);
        if (value is double) await prefs.setDouble(key, value);
      }
    } catch (_) {
      // Falha ao salvar não impede o uso nesta sessão.
    }
  }
}

final configurationProvider =
    NotifierProvider<ConfigurationNotifier, PerformanceSettings>(
  ConfigurationNotifier.new,
);
