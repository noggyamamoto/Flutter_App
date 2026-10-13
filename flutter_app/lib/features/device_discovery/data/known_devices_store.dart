import 'package:shared_preferences/shared_preferences.dart';

// Endereços em que o dispositivo já foi encontrado (o mais recente primeiro).
// Na próxima busca eles são consultados antes de tudo: o dispositivo
// costuma receber o mesmo IP do modem.
class KnownDevicesStore {
  static const _key = 'devices.knownAddresses';
  static const maxAddresses = 5;

  Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const [];
    } catch (_) {
      // Sem armazenamento (ex.: testes): segue sem histórico.
      return const [];
    }
  }

  Future<void> remember(String address) async {
    if (address.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = [
        address,
        ...(prefs.getStringList(_key) ?? const <String>[]).where((a) => a != address),
      ].take(maxAddresses).toList();
      await prefs.setStringList(_key, list);
    } catch (_) {
      // Falha ao gravar não impede a conexão.
    }
  }
}
