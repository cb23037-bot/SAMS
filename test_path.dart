import 'dart:io';

void main() {
  // Test if /Users/... resolves on Windows
  final path1 = '/Users/hizbu/.puro/envs/stable/flutter/bin/cache/flutter_web_sdk';
  final path2 = 'C:/Users/hizbu/.puro/envs/stable/flutter/bin/cache/flutter_web_sdk';
  final path3 = r'C:\Users\hizbu\.puro\envs\stable\flutter\bin\cache\flutter_web_sdk';

  print('Testing path resolution on Windows:');
  print('path1 ($path1): ${Directory(path1).existsSync()}');
  print('path2 ($path2): ${Directory(path2).existsSync()}');
  print('path3 ($path3): ${Directory(path3).existsSync()}');
  print('Uri.base: ${Uri.base}');
  print('Uri.file(path2).path: ${Uri.file(path2).path}');
  print('Uri.file(path1): ${Uri.file(path1)}');
}
