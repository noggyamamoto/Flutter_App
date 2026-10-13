import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/execution_console_log.dart';

// Log da execução no console. No navegador as linhas aparecem no console
// do DevTools (F12); no celular/computador, no terminal do `flutter run`.
final executionConsoleLogProvider = Provider<ExecutionConsoleLog>((ref) {
  return ExecutionConsoleLog((line) => debugPrint(line));
});
