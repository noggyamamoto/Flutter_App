import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      backgroundColor: const Color(0xFF0F0E17),

      appBar: widget.pushed
          ? AppBar(
              backgroundColor: const Color(0xFF0F0E17),
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

                    const Text(
                      'Sem o dispositivo por perto?',
                      style: TextStyle(
                        color: Colors.white70,
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
                        style: _outlinedStyle(const Color(0xFF9B6DDA)),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: busy ? null : _skip,
                      child: const Text(
                        'Continuar sem dispositivo',
                        style: TextStyle(color: Colors.white70),
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
          Colors.greenAccent,
          'Dispositivo conectado',
          'Tudo pronto para praticar.',
        ),
      DeviceConnectionStatus.searching => (
          Icons.wifi_find,
          const Color(0xFF9B6DDA),
          'Procurando dispositivos',
          'Mantenha o dispositivo ligado e na mesma rede Wi-Fi.',
        ),
      DeviceConnectionStatus.connecting => (
          Icons.link,
          const Color(0xFF9B6DDA),
          'Conectando...',
          'Aguardando a confirmação do dispositivo.',
        ),
      _ => (
          Icons.sensors_off,
          Colors.white54,
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
            color: const Color(0xFF232136),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
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
        color: const Color(0xFF232136),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF39374A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                device.isSimulated ? Icons.smart_toy_outlined : Icons.memory,
                color: const Color(0xFF9B6DDA),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  device.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!device.isSimulated) ...[
            _info('Endereço', device.address),
            _info('Firmware', device.firmware),
            if (state.rssi != null && state.rssi != 0)
              _info('Sinal Wi-Fi', '${state.rssi} dBm'),
            if (state.noiseFloorDb != null)
              _info('Ruído ambiente', '${state.noiseFloorDb!.toStringAsFixed(0)} dBFS'),
          ] else
            const Text(
              'As notas serão tocadas por um aluno virtual, com pequenos '
              'erros, para demonstrar o funcionamento do sistema.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
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
        color: const Color(0xFF232136),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF39374A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.memory, color: Color(0xFF9B6DDA), size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${device.address} · firmware ${device.firmware}'
                        '${device.busy ? ' · em uso' : ''}',
                        style: const TextStyle(
                          color: Colors.white54,
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
    return Icon(icon, color: Colors.white70);
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
      style: const TextStyle(color: Colors.white),
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: 'Conectar pelo IP (opcional)',
        hintText: 'ex.: 192.168.0.42',
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.lan_outlined, color: Colors.white70),
        suffixIcon: IconButton(
          onPressed: enabled ? onSubmit : null,
          icon: const Icon(Icons.arrow_forward, color: Colors.white70),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
