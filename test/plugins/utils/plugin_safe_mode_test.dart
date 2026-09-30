import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/plugins/utils/plugin_safe_mode.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dataRoot;

  setUp(() {
    dataRoot = Directory.systemTemp.createTempSync('safe-mode');
    AppPaths.debugOverrideDataRootPath(dataRoot.path);
  });

  tearDown(() {
    PluginSafeMode.resetForTesting();
    AppPaths.debugOverrideDataRootPath(null);
    dataRoot.deleteSync(recursive: true);
  });

  File marker() => File(p.join(dataRoot.path, 'safe_mode_session.json'));

  test('the flag is read in its accepted spellings', () {
    for (final arg in ['--safe-mode', '/safe-mode', '--SAFE_MODE']) {
      expect(isSafeModeFlag(arg), isTrue, reason: arg);
    }
    expect(isSafeModeFlag('--dev-plugins'), isFalse);
    expect(isSafeModeFlag('otzaria://plugin/install'), isFalse);
  });

  test('initFromArgs sets the mode without touching files', () {
    PluginSafeMode.initFromArgs(const ['--safe-mode']);
    expect(PluginSafeMode.isActive, isTrue);
    expect(marker().existsSync(), isFalse);

    PluginSafeMode.initFromArgs(const []);
    expect(PluginSafeMode.isActive, isFalse);
  });

  test('secondary windows of the same process follow the marker', () async {
    await PluginSafeMode.set(true);
    PluginSafeMode.resetForTesting();

    await PluginSafeMode.initForSecondaryWindow();
    expect(PluginSafeMode.isActive, isTrue);
  });

  test('a marker left by another process is ignored', () async {
    marker().writeAsStringSync(jsonEncode({'pid': pid + 1}));

    await PluginSafeMode.initForSecondaryWindow();
    expect(PluginSafeMode.isActive, isFalse);
  });

  test('turning safe mode off removes the marker', () async {
    await PluginSafeMode.set(true);
    expect(marker().existsSync(), isTrue);

    await PluginSafeMode.set(false);
    expect(marker().existsSync(), isFalse);
  });
}
