import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';

import '../../domain/entities/device.dart';
import '../providers/connection_provider.dart';

// Tela de conexão entre o dispositivo embarcado e o aplicativo
// (RU02 / RFA01 – seção 4.4.2.1 do TCC).
//
// Mostra o status da conexão e permite buscar e parear um dispositivo
// ativo na rede, conectar por IP, usar o modo demonstração ou seguir
// sem dispositivo.
class ConnectionPage extends ConsumerStatefulWidget {
  // true quando aberta a partir do repertório (tem botão de voltar).
  final bool pushed;

  const ConnectionPage({
    super.key,
    this.pushed = false,
  });

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage> {
  final ipController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Busca automaticamente ao abrir a tela pela primeira vez.
    Future.microtask(() {
      final state = ref.read(connectionProvider);
      final notifier = ref.read(connectionProvider.notifier);
      if (!state.searched && !state.isConnected && notifier.isNetworkSupported) {
        notifier.search();
      }
    });
  }

  @override
  void dispose() {
    ipController.dispose();
    super.dispose();
  }

  Future<void> _connect(Device device) async {
    final ok = await ref.read(connectionProvider.notifier).connect(device);
    if (ok && widget.pushed && mounted) Navigator.pop(context);
  }

  Future<void> _useSimulator() async {
    final ok = await ref.read(connectionProvider.notifier).useSimulator();
    if (ok && widget.pushed && mounted) Navigator.pop(context);
  }

  void _skip() {
    ref.read(connectionProvider.notifier).skip();
    if (widget.pushed) Navigator.pop(context);
  }

  Future<void> _searchByIp() async {
    final ip = ipController.text.trim();
    if (ip.isEmpty) return;
    FocusScope.of(context).unfocus();
    await ref.read(connectionProvider.notifier).search(address: ip);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionProvider);
    final notifier = ref.read(connectionProvider.notifier);
    final busy = state.status == DeviceConnectionStatus.searching ||
        state.status == DeviceConnectionStatus.connecting;

    return Scaffold(
      backgroundColor: context.colors.background,

      appBar: widget.pushed
          ? AppBar(
              backgroundColor: context.colors.background,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Dispositivo'),
            )
          : null,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  _StatusHeader(state: state),

                  const SizedBox(height: 28),

                  // ------------------------------------------------
                  // CONECTADO
                  // ------------------------------------------------
                  if (state.isConnected) ...[
                    _ConnectedCard(state: state),

                    const SizedBox(height: 24),

                    if (!widget.pushed)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _skip,
                          style: _primaryStyle(),
                          child: const Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : notifier.disconnect,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Desconectar com segurança'),
                        style: _outlinedStyle(Colors.redAccent),
                      ),
                    ),
                  ]

                  // ------------------------------------------------
                  // BUSCA
                  // ------------------------------------------------
                  else ...[
                    if (state.message != null) ...[
                      _MessageBox(message: state.message!),
                      const SizedBox(height: 16),
                    ],

                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : () => notifier.search(),
                        style: _primaryStyle(),
                        icon: state.status == DeviceConnectionStatus.searching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.wifi_find),
                        label: Text(
                          state.status == DeviceConnectionStatus.searching
                              ? 'Buscando...'
                              : 'Buscar dispositivos',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ...state.devices.map(
                      (device) => _DeviceTile(
                        device: device,
                        enabled: !busy,
                        connecting: state.status == DeviceConnectionStatus.connecting,
                        onTap: () => _connect(device),
                      ),
                    ),

                    if (notifier.isNetworkSupported) ...[
                      const SizedBox(height: 8),
                      _IpField(
                        controller: ipController,
                        enabled: !busy,
                        onSubmit: _searchByIp,
                      ),
                    ],

                    const SizedBox(height: 28),

                    Text(
                      'Sem o dispositivo por perto?',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : _useSimulator,
                        icon: const Icon(Icons.smart_toy_outlined),
                        label: const Text('Usar modo demonstração'),
                        style: _outlinedStyle(context.colors.primarySoft),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: busy ? null : _skip,
                      child: Text(
                        'Continuar sem dispositivo',
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _primaryStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  ButtonStyle _outlinedStyle(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.6)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ==========================================================
// CABEÇALHO COM O STATUS
// ==========================================================

class _StatusHeader extends StatelessWidget {
  final DeviceConnectionState state;

  const _StatusHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final connected = state.isConnected;

    final (IconData icon, Color color, String title, String subtitle) = switch (state.status) {
      DeviceConnectionStatus.connected when connected => (
          Icons.sensors,
          context.colors.positive,
          'Dispositivo conectado',
          'Tudo pronto para praticar.',
        ),
      DeviceConnectionStatus.searching => (
          Icons.wifi_find,
          context.colors.primarySoft,
          'Procurando dispositivos',
          'Mantenha o dispositivo ligado e na mesma rede Wi-Fi. '
              'Se ele não responder logo, toda a rede local é consultada '
              '(pode levar até 1 minuto no navegador).',
        ),
      DeviceConnectionStatus.connecting => (
          Icons.link,
          context.colors.primarySoft,
          'Conectando...',
          'Aguardando a confirmação do dispositivo.',
        ),
      _ => (
          Icons.sensors_off,
          context.colors.textMuted,
          'Nenhum dispositivo conectado',
          'Conecte-se ao dispositivo próximo ao seu instrumento.',
        ),
    };

    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: context.colors.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.7),
              width: 3,
            ),
          ),
          child: Icon(icon, color: color, size: 52),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ==========================================================
// CARTÃO DO DISPOSITIVO CONECTADO
// ==========================================================

class _ConnectedCard extends StatelessWidget {
  final DeviceConnectionState state;

  const _ConnectedCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final device = state.device!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                device.isSimulated ? Icons.smart_toy_outlined : Icons.memory,
                color: context.colors.primarySoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  device.name,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!device.isSimulated) ...[
            _info(context, 'Endereço', device.address),
            _info(context, 'Firmware', device.firmware),
            if (state.rssi != null && state.rssi != 0)
              _info(context, 'Sinal Wi-Fi', '${state.rssi} dBm'),
            if (state.noiseFloorDb != null)
              _info(context, 'Ruído ambiente', '${state.noiseFloorDb!.toStringAsFixed(0)} dBFS'),
          ] else
            Text(
              'As notas serão tocadas por um aluno virtual, com pequenos '
              'erros, para demonstrar o funcionamento do sistema.',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// ITEM DA LISTA DE DISPOSITIVOS
// ==========================================================

class _DeviceTile extends StatelessWidget {
  final Device device;
  final bool enabled;
  final bool connecting;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device,
    required this.enabled,
    required this.connecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.memory, color: context.colors.primarySoft, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${device.address} · firmware ${device.firmware}'
                        '${device.busy ? ' · em uso' : ''}',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _SignalIcon(rssi: device.rssi),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalIcon extends StatelessWidget {
  final int rssi;

  const _SignalIcon({required this.rssi});

  @override
  Widget build(BuildContext context) {
    final icon = rssi == 0
        ? Icons.wifi
        : rssi > -60
            ? Icons.network_wifi
            : rssi > -75
                ? Icons.network_wifi_2_bar
                : Icons.network_wifi_1_bar;
    return Icon(icon, color: context.colors.textSecondary);
  }
}

// ==========================================================
// CONEXÃO POR IP
// ==========================================================

class _IpField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;

  const _IpField({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: context.colors.textPrimary),
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: 'Conectar pelo IP (opcional)',
        hintText: 'ex.: 192.168.0.42',
        hintStyle: TextStyle(color: context.colors.textMuted),
        labelStyle: TextStyle(color: context.colors.textSecondary),
        prefixIcon: Icon(Icons.lan_outlined, color: context.colors.textSecondary),
        suffixIcon: IconButton(
          onPressed: enabled ? onSubmit : null,
          icon: Icon(Icons.arrow_forward, color: context.colors.textSecondary),
        ),
        filled: true,
        fillColor: context.colors.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ==========================================================
// MENSAGEM
// ==========================================================

class _MessageBox extends StatelessWidget {
  final String message;

  const _MessageBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
