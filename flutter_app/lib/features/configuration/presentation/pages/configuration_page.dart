import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/configuration_provider.dart';

// Configuração de preferências do usuário (RFA03 – seção 4.4.2.3 do TCC).
class ConfigurationPage extends ConsumerWidget {
  const ConfigurationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(configurationProvider);
    final notifier = ref.read(configurationProvider.notifier);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,

      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: const Text('Configurações'),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _SectionTitle('Aparência'),

                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            settings.lightMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            color: colors.primarySoft,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tema',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'O modo escuro é o padrão do aplicativo. O modo claro '
                                  'mantém os mesmos tons de violeta sobre fundo claro.',
                                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Escuro'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Claro'),
                          ),
                        ],
                        selected: {settings.lightMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) =>
                            notifier.update(settings.copyWith(lightMode: v.first)),
                        style: _segmentStyle(colors),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const _SectionTitle('Áudio'),

                _SwitchTile(
                  icon: Icons.queue_music,
                  title: 'Música guia',
                  subtitle: 'Toca a música de fundo para você acompanhar. Use fones de '
                      'ouvido para o som não interferir no microfone.',
                  value: settings.guideAudio,
                  onChanged: (v) => notifier.update(settings.copyWith(guideAudio: v)),
                ),

                _SwitchTile(
                  icon: Icons.av_timer,
                  title: 'Metrônomo sonoro',
                  subtitle: 'Clique a cada tempo para manter o andamento.',
                  value: settings.metronomeSound,
                  onChanged: (v) => notifier.update(settings.copyWith(metronomeSound: v)),
                ),

                _SwitchTile(
                  icon: Icons.lightbulb_outline,
                  title: 'Metrônomo visual',
                  subtitle: 'Luzes no dispositivo e na tela: azul (binário), '
                      'verde (ternário) e roxo (quaternário).',
                  value: settings.metronomeVisual,
                  onChanged: (v) => notifier.update(settings.copyWith(metronomeVisual: v)),
                ),

                const SizedBox(height: 12),
                const _SectionTitle('Andamento'),

                _SwitchTile(
                  icon: Icons.speed,
                  title: 'Ajuste automático de BPM',
                  subtitle: 'Reduz o andamento da próxima frase quando houver '
                      'dificuldade. Desligado, o app apenas sugere a redução.',
                  value: settings.autoTempo,
                  onChanged: (v) => notifier.update(settings.copyWith(autoTempo: v)),
                ),

                const SizedBox(height: 12),
                const _SectionTitle('Leitura da partitura'),

                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compassos por trecho',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Trechos menores deixam a leitura mais tranquila.',
                        style: TextStyle(color: colors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 2, label: Text('2')),
                          ButtonSegment(value: 4, label: Text('4')),
                          ButtonSegment(value: 8, label: Text('8')),
                        ],
                        selected: {settings.measuresPerPhrase},
                        onSelectionChanged: (v) =>
                            notifier.update(settings.copyWith(measuresPerPhrase: v.first)),
                        style: _segmentStyle(colors),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tamanho dos símbolos: ${(settings.zoom * 100).round()}%',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: settings.zoom,
                        min: 1.0,
                        max: 1.6,
                        divisions: 6,
                        activeColor: colors.primarySoft,
                        inactiveColor: colors.subtle,
                        label: '${(settings.zoom * 100).round()}%',
                        onChanged: (v) => notifier.update(settings.copyWith(zoom: v)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  'Dica: o microfone reconhece uma nota por vez. Toque a melodia '
                  '(pauta superior); as notas em cinza são o acompanhamento.',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _segmentStyle(AppColors colors) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : colors.textSecondary,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.deepPurple
            : Colors.transparent,
      ),
      side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _Card(
      child: Row(
        children: [
          Icon(icon, color: colors.primarySoft, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.deepPurple,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
