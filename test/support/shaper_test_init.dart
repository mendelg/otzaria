import 'dart:convert';
import 'dart:io';

Directory? resolvedTestPackageRoot(String packageName) {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) return null;
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = config['packages'] as List<dynamic>;
  for (final package in packages) {
    if (package['name'] != packageName) continue;
    final rootUri = Uri.parse(package['rootUri'] as String);
    return Directory.fromUri(
      configFile.absolute.parent.uri.resolveUri(rootUri),
    );
  }
  return null;
}

String? findNativeShaperLibrary() {
  final root = resolvedTestPackageRoot('opentype_shaper');
  final name = Platform.isWindows
      ? 'opentype_shaper.dll'
      : Platform.isMacOS
      ? 'libopentype_shaper.dylib'
      : 'libopentype_shaper.so';
  if (root != null) {
    for (final profile in const ['release', 'debug']) {
      final file = File('${root.path}/rust/target/$profile/$name');
      if (file.existsSync()) return file.absolute.path;
    }
  }
  if (Platform.environment['CI'] == 'true') {
    throw StateError('OpenType shaper was not built in the resolved package.');
  }
  return null;
}
