import 'dart:io';

void main() {
  final path = '/Users/hizbu/.puro/envs/stable/flutter/bin/cache/flutter_web_sdk/';

  // Test various ways the frontend server might check the path
  final uri1 = Uri.parse(path);
  print('Uri.parse(path): $uri1');
  print('uri1.toFilePath(): ${uri1.toFilePath()}');
  print('Dir.fromUri(uri1).existsSync(): ${Directory.fromUri(uri1).existsSync()}');
  print('');

  final uri2 = Uri.file(path);
  print('Uri.file(path): $uri2');
  print('Dir.fromUri(uri2).existsSync(): ${Directory.fromUri(uri2).existsSync()}');
  print('');

  // What about with trailing dot?
  final pathDot = path + '.';
  print('With trailing dot: $pathDot');
  final uri3 = Uri.parse(pathDot);
  print('Uri.parse(pathDot): $uri3');
  print('uri3.path: ${uri3.path}');

  try {
    print('Dir.fromUri(uri3).existsSync(): ${Directory.fromUri(uri3).existsSync()}');
  } catch (e) {
    print('Dir.fromUri(uri3) threw: $e');
  }
}
