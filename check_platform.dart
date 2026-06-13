import 'dart:io';
void main() {
  print('Platform.script: ${Platform.script}');
  print('Platform.resolvedExecutable: ${Platform.resolvedExecutable}');
  print('FLUTTER_ROOT env: ${Platform.environment['FLUTTER_ROOT'] ?? 'NOT SET'}');
  print('PURO_FLUTTER_BIN env: ${Platform.environment['PURO_FLUTTER_BIN'] ?? 'NOT SET'}');
  print('isWindows: ${Platform.isWindows}');
}
