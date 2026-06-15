import 'dart:io';

// Simulate what frontend_server_aot.dart.snapshot does with --sdk-root
// The error: "SDK root directory not found: /Users/hizbu/.../flutter_web_sdk/."

void main() {
  const sdkRoot = '/Users/hizbu/.puro/envs/stable/flutter/bin/cache/flutter_web_sdk/';

  print('=== Simulating frontend_server sdk-root validation ===');
  print('Input sdkRoot: $sdkRoot');
  print('');

  // Method 1: Uri.base.resolve(sdkRoot)
  print('Uri.base: ${Uri.base}');
  final resolved = Uri.base.resolve(sdkRoot);
  print('Uri.base.resolve(sdkRoot): $resolved');
  try {
    final fp = resolved.toFilePath();
    print('resolved.toFilePath(): $fp');
    print('Directory(resolved.toFilePath()).existsSync(): ${Directory(fp).existsSync()}');
  } catch (e) {
    print('toFilePath() threw: $e');
  }
  print('');

  // Method 2: Uri.file(sdkRoot)
  print('Trying Uri.file(sdkRoot):');
  try {
    final uri2 = Uri.file(sdkRoot);
    print('Uri.file(sdkRoot): $uri2');
    final fp2 = uri2.toFilePath();
    print('uri2.toFilePath(): $fp2');
    print('Directory(fp2).existsSync(): ${Directory(fp2).existsSync()}');
  } catch (e) {
    print('Uri.file(sdkRoot) threw: $e');
  }
  print('');

  // Method 3: Uri.directory(sdkRoot)
  print('Trying Uri.directory(sdkRoot):');
  try {
    final uri3 = Uri.directory(sdkRoot);
    print('Uri.directory(sdkRoot): $uri3');
    final fp3 = uri3.toFilePath();
    print('uri3.toFilePath(): $fp3');
    print('Directory(fp3).existsSync(): ${Directory(fp3).existsSync()}');
  } catch (e) {
    print('Uri.directory(sdkRoot) threw: $e');
  }
  print('');

  // Method 4: What does _ensureFolderPath likely do?
  // From frontend_server source: converts path to URI path
  print('Testing _ensureFolderPath equivalent:');
  String path = sdkRoot;
  // Try: Uri.parse(path).path
  final parsedPath = Uri.parse(path).path;
  print('Uri.parse(sdkRoot).path: $parsedPath');
  print('Directory(parsedPath).existsSync(): ${Directory(parsedPath).existsSync()}');
  print('');

  // Method 5: The actual likely flow - check if startsWith('file://')
  print('Checking if sdkRoot starts with "file://": ${sdkRoot.startsWith('file://')}');
  // Frontend server likely wraps with file:// if missing
  final sdkRootUri = Uri.parse('file://' + (sdkRoot.startsWith('/') ? '' : '/') + sdkRoot);
  print('file://-prefixed URI: $sdkRootUri');
  try {
    final fp5 = sdkRootUri.toFilePath();
    print('toFilePath(): $fp5');
    print('Directory(fp5).existsSync(): ${Directory(fp5).existsSync()}');
  } catch (e) {
    print('toFilePath() threw: $e');
  }
}
