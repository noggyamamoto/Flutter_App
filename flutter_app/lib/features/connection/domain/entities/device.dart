// Dispositivo embarcado encontrado na rede.
class Device {
  // Identificador único (endereço MAC).
  final String id;

  // Nome amigável (ex.: PartituraIoT-3A7F).
  final String name;

  // Endereço IP e porta UDP.
  final String address;
  final int port;

  // Versão do firmware.
  final String firmware;

  // Intensidade do sinal Wi-Fi (dBm).
  final int rssi;

  // Indica se o dispositivo já está pareado com outro app.
  final bool busy;

  // Dispositivo virtual usado no modo demonstração.
  final bool isSimulated;

  const Device({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.firmware,
    this.rssi = 0,
    this.busy = false,
    this.isSimulated = false,
  });
}
