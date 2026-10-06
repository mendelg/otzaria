import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/empty_library/bloc/empty_library_bloc.dart';
import 'package:otzaria/empty_library/bloc/empty_library_event.dart';
import 'package:otzaria/empty_library/bloc/empty_library_state.dart';
import 'package:otzaria/empty_library/services/library_package/library_package.dart';
import 'package:otzaria/empty_library/services/library_package/library_package_extractor.dart';
import 'package:otzaria/empty_library/services/library_package/library_package_importer.dart';
import 'package:otzaria/empty_library/services/library_package/package_folder.dart';
import 'package:otzaria/library_update/services/library_access_gate.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/utils/file/disk_free_space.dart';
import 'package:otzaria/utils/file/zstd_patch_decoder.dart';
import 'package:path/path.dart' as p;

import '../support/zstd_test_lib.dart';
import '../test_helpers/memory_cache_provider.dart';
import 'library_package_test_support.dart';

const _library = 'otzaria-0.9.98-library.tar.zst';
const _index = 'otzaria-0.9.98-library-index.tar.zst';
final _dbName = DatabaseConstants.databaseFileName;

Uint8List _noise(int length, int seed) {
  final random = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

/// השעיית המסד בלי חלונות אחרים; [resumed] מסמן שהמטפל סיים, כולל ניקוי הגיבוי.
class _Gate extends LibraryAccessGate {
  _Gate()
    : super(
        selfAccess: LibraryAccessRoutine(
          suspend: () async {},
          resume: (_) async {},
        ),
        renameProbe: false,
        logError: (_, _, _) {},
      );

  final resumed = Completer<void>();

  @override
  Future<void> resumeAll(
    LibrarySuspension suspension, {
    required bool dbReplaced,
  }) async {
    await super.resumeAll(suspension, dbReplaced: dbReplaced);
    if (!resumed.isCompleted) resumed.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lib = openZstdForTests();

  late Directory temp;
  late Directory source;
  late String root;
  late String books;
  late List<String> indexHostCalls;
  late _Gate gate;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('otzaria-pkg-bloc-');
    EmptyLibraryBloc.tempRootOverride = temp.path;
    source = await Directory(p.join(temp.path, 'הורדות')).create();
    root = p.join(temp.path, 'ספרייה');
    books = p.join(root, 'books');
    indexHostCalls = [];
    await Settings.init(cacheProvider: MemoryCacheProvider());
    await Settings.setValue<String>(SettingsRepository.keyLibraryPath, '');
    await Settings.setValue<String>(SettingsRepository.keyIndexPath, '');
  });

  tearDown(() async {
    EmptyLibraryBloc.tempRootOverride = null;
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  void writeLibrary(DynamicLibrary lib) {
    final archive = zstdCompress(
      lib,
      buildTar({
        'books/$_dbName': utf8.encode('new-db'),
        'books/תלמוד בבלי/ברכות.pdf': _noise(400000, 3),
      }),
    );
    writeSplitAsset(source, _library, archive, partSize: 65536);
  }

  void writeIndex(DynamicLibrary lib) {
    final archive = zstdCompress(
      lib,
      buildTar({
        'index/${AppPaths.prebuiltIndexMarkerFileName}': const [],
        'index/meta.json': utf8.encode('{"new":true}'),
      }),
    );
    writeSplitAsset(source, _index, archive, partSize: 65536);
  }

  /// הפריסה האמיתית, בלי isolate: ב-isolate של בדיקה אין את ה-DLL של zstd.
  Future<void> inlineRunner(
    PackageExtractionJob job, {
    required PackageExtractionProgress onProgress,
    required ZstdCancelFlag cancel,
  }) {
    final cell = Pointer<Uint8>.fromAddress(cancel.address);
    return extractPackageJob(
      job,
      zstd: lib!,
      onProgress: onProgress,
      isCancelled: () => cell.value != 0,
    );
  }

  EmptyLibraryBloc build({int freeBytes = -1}) => EmptyLibraryBloc(
    accessGate: gate = _Gate(),
    downloadSpaceChecker: (_) async => null,
    packageImporter: LibraryPackageImporter(
      runner: inlineRunner,
      diskSpace: (_) async =>
          DiskSpaceInfo(volumeId: 'test', freeBytes: freeBytes),
      indexHost: LibraryIndexHost(
        release: () async => indexHostCalls.add('release'),
        reopen: () async => indexHostCalls.add('reopen'),
      ),
    ),
  );

  Future<LibraryPackageSet> scanned() async => (await scanLibraryPackages(
    DirectoryPackageFolder(source.path),
  )).packages!;

  /// עדכון במקום מסתיים ב-resumeAll; הגדרה ראשונה — במצב הסופי.
  Future<void> settle(EmptyLibraryBloc bloc, {bool replacing = false}) async {
    if (replacing) {
      await gate.resumed.future.timeout(const Duration(seconds: 30));
      return;
    }
    await bloc.stream
        .firstWhere(
          (s) => s is EmptyLibraryDirectorySelected || s is EmptyLibraryError,
        )
        .timeout(const Duration(seconds: 30));
    await pumpEventQueue();
  }

  void expectNoLeftovers() {
    expect(Directory('$books.import').existsSync(), isFalse);
    expect(Directory(EmptyLibraryBloc.dbBackupDirPath).existsSync(), isFalse);
  }

  late LibraryPackageSet packages;

  blocTest<EmptyLibraryBloc, EmptyLibraryState>(
    'הגדרה ראשונה: הספרייה והאינדקס נפרסים, וההגדרות מצביעות עליהם',
    setUp: () async {
      if (lib == null) return;
      writeLibrary(lib);
      writeIndex(lib);
      packages = await scanned();
    },
    build: build,
    act: (bloc) async {
      if (lib == null) return markTestSkipped('libzstd אינו זמין');
      bloc.add(
        ImportLibraryPackageRequested(packages: packages, targetPath: books),
      );
      await settle(bloc);
    },
    verify: (bloc) {
      if (lib == null) return;
      expect(bloc.state, isA<EmptyLibraryDirectorySelected>());
      expect(File(p.join(books, _dbName)).readAsStringSync(), 'new-db');
      expect(
        File(p.join(books, 'תלמוד בבלי', 'ברכות.pdf')).lengthSync(),
        400000,
      );
      final index = p.join(root, 'index');
      expect(
        File(p.join(index, AppPaths.prebuiltIndexMarkerFileName)).existsSync(),
        isTrue,
      );
      expect(
        Settings.getValue<String>(SettingsRepository.keyLibraryPath),
        books,
      );
      expect(Settings.getValue<String>(SettingsRepository.keyIndexPath), index);
      expect(indexHostCalls, ['release', 'reopen']);
      expectNoLeftovers();
    },
  );

  blocTest<EmptyLibraryBloc, EmptyLibraryState>(
    'ההתקדמות ניתנת לביטול בזמן הפריסה, ולא בזמן ההעברה למקום',
    setUp: () async {
      if (lib == null) return;
      writeLibrary(lib);
      packages = await scanned();
    },
    build: build,
    act: (bloc) async {
      if (lib == null) return;
      bloc.add(
        ImportLibraryPackageRequested(packages: packages, targetPath: books),
      );
      await settle(bloc);
    },
    verify: (bloc) {},
    expect: () => lib == null
        ? const <EmptyLibraryState>[]
        : containsAllInOrder([
            isA<EmptyLibraryExtracting>().having(
              (s) => s.cancellable,
              'cancellable',
              isTrue,
            ),
            isA<EmptyLibraryExtracting>()
                .having((s) => s.cancellable, 'cancellable', isFalse)
                .having((s) => s.progress, 'progress', 1.0),
            isA<EmptyLibraryDirectorySelected>(),
          ]),
  );

  blocTest<EmptyLibraryBloc, EmptyLibraryState>(
    'העברת הספרים נכשלה אחרי החלפת האינדקס: האינדקס הקודם חוזר',
    setUp: () async {
      if (lib == null) return;
      writeLibrary(lib);
      writeIndex(lib);
      packages = await scanned();
      // תיקייה בשם המסד ביעד מכשילה את ה-rename האחרון של ההעברה.
      await Directory(p.join(books, _dbName, 'x')).create(recursive: true);
      await Directory(p.join(root, 'index')).create();
      await File(p.join(root, 'index', 'meta.json')).writeAsString('old');
    },
    build: build,
    act: (bloc) async {
      if (lib == null) return;
      bloc.add(
        ImportLibraryPackageRequested(packages: packages, targetPath: books),
      );
      await settle(bloc);
    },
    verify: (bloc) {
      if (lib == null) return;
      expect(bloc.state, isA<EmptyLibraryError>());
      expect(
        File(p.join(root, 'index', 'meta.json')).readAsStringSync(),
        'old',
      );
      expect(Directory(p.join(root, 'index.replaced')).existsSync(), isFalse);
      expect(Settings.getValue<String>(SettingsRepository.keyIndexPath), '');
      expect(indexHostCalls, ['release', 'reopen']);
      expectNoLeftovers();
    },
  );

  group('ספרייה קיימת', () {
    setUp(() async {
      await Directory(books).create(recursive: true);
      await File(p.join(books, _dbName)).writeAsString('old-db');
      await Directory(p.join(root, 'index')).create();
      await File(p.join(root, 'index', 'meta.json')).writeAsString('old');
      await Settings.setValue<String>(SettingsRepository.keyLibraryPath, books);
    });

    void expectOldLibraryIntact() {
      expect(File(p.join(books, _dbName)).readAsStringSync(), 'old-db');
      expect(
        File(p.join(root, 'index', 'meta.json')).readAsStringSync(),
        'old',
      );
      expectNoLeftovers();
    }

    blocTest<EmptyLibraryBloc, EmptyLibraryState>(
      'עדכון במקום מחליף את הספרייה ואת האינדקס',
      setUp: () async {
        if (lib == null) return;
        writeLibrary(lib);
        writeIndex(lib);
        packages = await scanned();
      },
      build: build,
      act: (bloc) async {
        if (lib == null) return;
        bloc.add(
          ImportLibraryPackageRequested(
            packages: packages,
            targetPath: books,
            backupExistingPath: books,
          ),
        );
        await settle(bloc, replacing: true);
      },
      verify: (bloc) {
        if (lib == null) return;
        expect(bloc.state, isA<EmptyLibraryDirectorySelected>());
        expect(File(p.join(books, _dbName)).readAsStringSync(), 'new-db');
        expect(
          File(p.join(root, 'index', 'meta.json')).readAsStringSync(),
          '{"new":true}',
        );
        expect(Directory(p.join(root, 'index.replaced')).existsSync(), isFalse);
        expectNoLeftovers();
      },
    );

    blocTest<EmptyLibraryBloc, EmptyLibraryState>(
      'חלק פגום: שגיאה עם שם החלק, והספרייה הקיימת לא נפגעת',
      setUp: () async {
        if (lib == null) return;
        writeLibrary(lib);
        writeIndex(lib);
        final part = File(p.join(source.path, '$_library.part-002'));
        final bytes = part.readAsBytesSync()..[100] ^= 0xFF;
        part.writeAsBytesSync(bytes);
        packages = await scanned();
      },
      build: build,
      act: (bloc) async {
        if (lib == null) return;
        bloc.add(
          ImportLibraryPackageRequested(
            packages: packages,
            targetPath: books,
            backupExistingPath: books,
          ),
        );
        await settle(bloc, replacing: true);
      },
      verify: (bloc) {
        if (lib == null) return;
        final state = bloc.state as EmptyLibraryError;
        expect(state.errorMessage, contains('$_library.part-002'));
        expect(indexHostCalls, isEmpty);
        expectOldLibraryIntact();
      },
    );

    blocTest<EmptyLibraryBloc, EmptyLibraryState>(
      'ביטול באמצע הפריסה: הספרייה הקיימת נשארת ואין שאריות staging',
      setUp: () async {
        if (lib == null) return;
        writeLibrary(lib);
        packages = await scanned();
      },
      build: build,
      act: (bloc) async {
        if (lib == null) return;
        final sub = bloc.stream.listen((s) {
          if (s is EmptyLibraryExtracting && s.cancellable && s.progress > 0) {
            bloc.add(CancelLibraryImportRequested());
          }
        });
        bloc.add(
          ImportLibraryPackageRequested(
            packages: packages,
            targetPath: books,
            backupExistingPath: books,
          ),
        );
        await settle(bloc, replacing: true);
        await sub.cancel();
      },
      verify: (bloc) {
        if (lib == null) return;
        final state = bloc.state as EmptyLibraryError;
        expect(state.errorMessage, contains('בוטל'));
        expectOldLibraryIntact();
      },
    );

    blocTest<EmptyLibraryBloc, EmptyLibraryState>(
      'אין מספיק מקום: נעצר לפני כל כתיבה',
      setUp: () async {
        if (lib == null) return;
        writeLibrary(lib);
        packages = await scanned();
      },
      build: () => build(freeBytes: 1000),
      act: (bloc) async {
        if (lib == null) return;
        bloc.add(
          ImportLibraryPackageRequested(
            packages: packages,
            targetPath: books,
            backupExistingPath: books,
          ),
        );
        await settle(bloc, replacing: true);
      },
      verify: (bloc) {
        if (lib == null) return;
        final state = bloc.state as EmptyLibraryError;
        expect(state.errorMessage, contains('אין מספיק מקום'));
        expectOldLibraryIntact();
      },
    );
  });
}
