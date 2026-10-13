// Endereços em que o app procura o dispositivo embarcado.
//
// A busca acontece em duas etapas:
//  1. Rápida: broadcast UDP (celular/computador), os endereços em que o
//     dispositivo já foi encontrado antes, o nome fixo anunciado pelo
//     firmware por mDNS (partitura.local) e o IP da rede própria do
//     dispositivo (modo AP, 192.168.4.1).
//  2. Varredura: se nada respondeu, consulta cada endereço das sub-redes
//     locais. No navegador não há broadcast nem como saber a sub-rede do
//     computador, então são consultadas as sub-redes já usadas e as mais
//     comuns dos modems domésticos.
class DiscoveryTargets {
  // Nome anunciado pelo firmware (MDNS_HOSTNAME no config.h).
  static const mdnsHost = 'partitura.local';

  // IP do dispositivo na rede própria dele (modo AP).
  static const accessPointAddress = '192.168.4.1';

  // Sub-redes /24 mais comuns em modems domésticos e de operadoras.
  static const commonSubnets = [
    '192.168.0',
    '192.168.1',
    '192.168.15',
    '192.168.100',
    '10.0.0',
    '192.168.2',
    '192.168.3',
    '192.168.10',
  ];

  // Endereços da etapa rápida, sem repetição, na ordem de prioridade.
  static List<String> quick(List<String> known) {
    return {...known, mdnsHost, accessPointAddress}.toList();
  }

  // Prefixo /24 de um endereço IPv4 (ex.: 192.168.0.42 -> 192.168.0).
  static String? prefixOf(String address) {
    final parts = address.split('.');
    if (parts.length != 4) return null;
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return null;
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  // Sub-redes a varrer: as das interfaces locais, as dos endereços já usados
  // e, quando `includeCommon`, as mais comuns. Sem a rede própria (já
  // consultada na etapa rápida).
  static List<String> subnets({
    List<String> local = const [],
    List<String> known = const [],
    bool includeCommon = false,
  }) {
    final result = <String>{};
    for (final prefix in local) {
      result.add(prefix);
    }
    for (final address in known) {
      final prefix = prefixOf(address);
      if (prefix != null) result.add(prefix);
    }
    if (includeCommon) result.addAll(commonSubnets);
    result.remove(prefixOf(accessPointAddress));
    return result.toList();
  }

  // Endereços de uma sub-rede /24 (1 a 254).
  static List<String> hostsOf(String prefix) => [
        for (var i = 1; i <= 254; i++) '$prefix.$i',
      ];
}
