import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/configuration_provider.dart';

// Configuração de preferências do usuário (RFA03 – seção 4.4.2.3 do TCC).
class ConfigurationPage extends ConsumerWidget {
  const ConfigurationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(configurationProvider);
    final notifier = ref.read(configurationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        foregroundColor: Colors.white,
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
                      const Text(
                        'Compassos por trecho',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Trechos menores deixam a leitura mais tranquila.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
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
                        style: _segmentStyle(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tamanho dos símbolos: ${(settings.zoom * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: settings.zoom,
                        min: 1.0,
                        max: 1.6,
                        divisions: 6,
                        activeColor: const Color(0xFF9B6DDA),
                        label: '${(settings.zoom * 100).round()}%',
                        onChanged: (v) => notifier.update(settings.copyWith(zoom: v)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Dica: o microfone reconhece uma nota por vez. Toque a melodia '
                  '(pauta superior); as notas em cinza são o acompanhamento.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _segmentStyle() {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white70,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.deepPurple
            : Colors.transparent,
      ),
      side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF39374A))),
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
        style: const TextStyle(
          color: Colors.white,
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
        color: const Color(0xFF232136),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF39374A)),
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
    return _Card(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9B6DDA), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
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
