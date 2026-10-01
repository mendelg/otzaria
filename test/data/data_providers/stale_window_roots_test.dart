import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/data/data_providers/hive_data_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dataRoot;

  setUp(() {
    dataRoot = Directory.systemTemp.createTempSync('window-roots');
    AppPaths.debugOverrideDataRootPath(dataRoot.path);
  });

  tearDown(() {
    AppPaths.debugOverrideDataRootPath(null);
    dataRoot.deleteSync(recursive: true);
  });

  Directory windows() => Directory(p.join(dataRoot.path, windowRootsDirName));

  test('stale roots are moved aside at once and deleted afterwards', () async {
    File(p.join(windows().path, 'slot-1', 'app_preferences.hive'))
      ..createSync(recursive: true)
      ..writeAsStringSync('stale');

    await deleteStaleWindowRoots();
    expect(windows().existsSync(), isFalse);

    // A window opened while the deletion runs keeps its new folder.
    final fresh = Directory(p.join(windows().path, 'slot-2'))
      ..createSync(recursive: true);
    await pendingStaleRootsDeletion;

    expect(fresh.existsSync(), isTrue);
    expect(dataRoot.listSync().map((e) => p.basename(e.path)), [
      windowRootsDirName,
    ]);
  });

  test('folders left by an unfinished deletion are removed too', () async {
    Directory(
      p.join(dataRoot.path, '$windowRootsDirName.stale-1'),
    ).createSync();

    await deleteStaleWindowRoots();
    await pendingStaleRootsDeletion;

    expect(dataRoot.listSync(), isEmpty);
  });
}
