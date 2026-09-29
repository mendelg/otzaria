import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library_update/services/update_sqlite_setup.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:seforim_library_updater/seforim_library_updater.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempPath);

  final String tempPath;
  int calls = 0;

  @override
  Future<String?> getTemporaryPath() async {
    calls++;
    return tempPath;
  }
}

/// מחליף את המשתנה הגלובלי של SQLite, כדי שהבדיקה לא תשנה את התהליך.
class _FakeSqliteTempDir {
  _FakeSqliteTempDir([this.value]);

  String? value;
  final writes = <String>[];

  String? read() => value;

  void write(String path) {
    writes.add(path);
    value = path;
  }
}

void main() {
  const mib = 1024;

  group('applierForPhysicalRam', () {
    PatchApplier sized(int? ramMb) =>
        LibraryUpdateSqliteSetup.applierForPhysicalRam(ramMb);

    test('8GB ומעלה — ברירות המחדל של ה-updater', () {
      const defaults = PatchApplier();
      for (final ram in [8192, 16384, 65536]) {
        expect(sized(ram).cacheSizeKib, defaults.cacheSizeKib, reason: '$ram');
        expect(sized(ram).hashCacheSizeKib, defaults.hashCacheSizeKib);
      }
    });

    test('היחס של 8GB נשמר ברצף עם ברירות המחדל', () {
      const defaults = PatchApplier();
      expect(8192 * mib ~/ 32, defaults.cacheSizeKib);
      expect(8192 * mib ~/ 128, defaults.hashCacheSizeKib);
    });

    test('מכשירי 2–4GB מקבלים 1/32 ו-1/128 של ה-RAM', () {
      expect(sized(2048).cacheSizeKib, 64 * mib);
      expect(sized(2048).hashCacheSizeKib, 16 * mib);
      expect(sized(3072).cacheSizeKib, 96 * mib);
      expect(sized(3072).hashCacheSizeKib, 24 * mib);
      expect(sized(4096).cacheSizeKib, 128 * mib);
      expect(sized(4096).hashCacheSizeKib, 32 * mib);
    });

    test('RAM לא ידוע או לא תקין — ההנחה השמרנית של 2GB', () {
      for (final ram in [null, 0, -1]) {
        expect(sized(ram).cacheSizeKib, 64 * mib, reason: '$ram');
        expect(sized(ram).hashCacheSizeKib, 16 * mib);
      }
      expect(LibraryUpdateSqliteSetup.fallbackRamMb, 2048);
    });
  });

  group('prepareApplier', () {
    late Directory tmp;
    late PathProviderPlatform originalPathProvider;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('update_sqlite_setup_test');
      originalPathProvider = PathProviderPlatform.instance;
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      tmp.deleteSync(recursive: true);
    });

    test(
      'desktop: ברירות מחדל, בלי path_provider ובלי לגעת ב-SQLite',
      () async {
        final fakePath = _FakePathProvider(tmp.path);
        PathProviderPlatform.instance = fakePath;
        final global = _FakeSqliteTempDir();
        var ramCalls = 0;
        final setup = LibraryUpdateSqliteSetup(
          isMobile: false,
          physicalRamMb: () async {
            ramCalls++;
            return 2048;
          },
          readSqliteTempDirectory: global.read,
          writeSqliteTempDirectory: global.write,
        );

        final applier = await setup.prepareApplier();

        expect(applier.cacheSizeKib, const PatchApplier().cacheSizeKib);
        expect(fakePath.calls, 0);
        expect(ramCalls, 0);
        expect(global.writes, isEmpty);
      },
    );

    test(
      'mobile: תיקיית ה-temp של path_provider נכתבת ל-SQLite ונוצרת',
      () async {
        final tempPath = p.join(tmp.path, 'cache');
        final fakePath = _FakePathProvider(tempPath);
        PathProviderPlatform.instance = fakePath;
        final global = _FakeSqliteTempDir();
        final setup = LibraryUpdateSqliteSetup(
          isMobile: true,
          needsSqliteTempDirectory: true,
          physicalRamMb: () async => 3072,
          readSqliteTempDirectory: global.read,
          writeSqliteTempDirectory: global.write,
        );

        final applier = await setup.prepareApplier();

        expect(global.writes, [tempPath]);
        expect(Directory(tempPath).existsSync(), isTrue);
        expect(applier.cacheSizeKib, 96 * mib);
        expect(applier.hashCacheSizeKib, 24 * mib);
      },
    );

    test('mobile: ערך קיים לא נדרס (דריסה משחררת מחרוזת בשימוש)', () async {
      final fakePath = _FakePathProvider(tmp.path);
      PathProviderPlatform.instance = fakePath;
      final global = _FakeSqliteTempDir('/already/set');
      final setup = LibraryUpdateSqliteSetup(
        isMobile: true,
        needsSqliteTempDirectory: true,
        physicalRamMb: () async => 4096,
        readSqliteTempDirectory: global.read,
        writeSqliteTempDirectory: global.write,
      );

      await setup.prepareApplier();

      expect(global.writes, isEmpty);
      expect(global.value, '/already/set');
      expect(fakePath.calls, 0);
    });

    test('mobile: קריאות חוזרות ומקבילות מגדירות פעם אחת בלבד', () async {
      final fakePath = _FakePathProvider(tmp.path);
      PathProviderPlatform.instance = fakePath;
      final global = _FakeSqliteTempDir();
      final setup = LibraryUpdateSqliteSetup(
        isMobile: true,
        needsSqliteTempDirectory: true,
        physicalRamMb: () async => 2048,
        readSqliteTempDirectory: global.read,
        writeSqliteTempDirectory: global.write,
      );

      final results = await Future.wait([
        setup.prepareApplier(),
        setup.prepareApplier(),
      ]);
      await setup.prepareApplier();

      expect(identical(results[0], results[1]), isTrue);
      expect(fakePath.calls, 1);
      expect(global.writes, [tmp.path]);
    });

    test('mobile: ברירת המחדל כותבת למשתנה הגלובלי האמיתי של SQLite', () async {
      if (sqlite3.sqlite3.tempDirectory != null) {
        markTestSkipped('sqlite3_temp_directory כבר מוגדר בתהליך');
        return;
      }
      // תיקיית המערכת ולא tmp: הערך נשאר בתהליך אחרי שה-tmp נמחק.
      final systemTemp = Directory.systemTemp.path;
      PathProviderPlatform.instance = _FakePathProvider(systemTemp);
      final setup = LibraryUpdateSqliteSetup(
        isMobile: true,
        needsSqliteTempDirectory: true,
        physicalRamMb: () async => 2048,
      );

      await setup.prepareApplier();

      expect(sqlite3.sqlite3.tempDirectory, systemTemp);
    });

    test('iOS: cache לפי ה-RAM בלי לגעת בתיקיית ה-temp של SQLite', () async {
      final fakePath = _FakePathProvider(tmp.path);
      PathProviderPlatform.instance = fakePath;
      final global = _FakeSqliteTempDir();
      final setup = LibraryUpdateSqliteSetup(
        isMobile: true,
        needsSqliteTempDirectory: false,
        physicalRamMb: () async => 4096,
        readSqliteTempDirectory: global.read,
        writeSqliteTempDirectory: global.write,
      );

      final applier = await setup.prepareApplier();

      expect(applier.cacheSizeKib, 128 * mib);
      expect(fakePath.calls, 0);
      expect(global.writes, isEmpty);
    });

    test('mobile: כשל בקריאת ה-RAM נופל להנחת 2GB', () async {
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
      final global = _FakeSqliteTempDir();
      final setup = LibraryUpdateSqliteSetup(
        isMobile: true,
        needsSqliteTempDirectory: true,
        physicalRamMb: () async => throw StateError('no channel'),
        readSqliteTempDirectory: global.read,
        writeSqliteTempDirectory: global.write,
      );

      final applier = await setup.prepareApplier();

      expect(applier.cacheSizeKib, 64 * mib);
      expect(global.writes, [tmp.path]);
    });
  });
}
