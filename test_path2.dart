import 'dart:io';
import 'dart:convert';

void main() {
  final base = '/Users/hizbu/.puro/envs/stable/flutter/bin/cache/flutter_web_sdk';

  print('base exists: ${Directory(base).existsSync()}');
  print('base/. exists: ${Directory(base + '/.').existsSync()}');
  print('base + . exists: ${Directory(base + '.').existsSync()}');

  // Simulate what frontend_server does
  final uri = Uri.file(base);
  print('Uri.file(base): $uri');
  print('uri.path: ${uri.path}');
  print('uri.toFilePath(): ${uri.toFilePath()}');

  // Check with trailing slash
  final baseSlash = base + '/';
  final uri2 = Uri.file(baseSlash);
  print('Uri.file(base/): $uri2');
  print('uri2.path: ${uri2.path}');

  // Resolve . against the URI
  final uriDot = uri.resolve('.');
  print('uri.resolve("."): $uriDot');
  print('uriDot.path: ${uriDot.path}');
  print('Dir(uriDot.path).exists: ${Directory(uriDot.path).existsSync()}');
}
