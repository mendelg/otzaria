import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/data/data_providers/db_read_worker.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/data_providers/user_books_database_holder.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/line_content_codec.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/migration/models/book.dart' as migration_models;
import 'package:otzaria/migration/models/category.dart' as migration_models;
import 'package:otzaria/migration/models/line.dart' as migration_models;
import 'package:otzaria/models/books.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/text_book/view/error_report_dialog.dart';
import 'package:otzaria/tools/dictionary/repository/db_dictionary_book_source.dart';
import 'package:otzaria/utils/file/zstd_library.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../support/zstd_test_lib.dart';
import '../test_helpers/memory_cache_provider.dart';

const _title = 'ספר דחוס';
final _lines = [for (var i = 0; i < 30; i++) 'שורה $i של הספר'];

/// קריאות טקסט שורה ממסד דחוס לא מפענחות על ה-UI isolate: ה-codec המזויף
/// כאן נטען רק ב-isolate הראשי, ורושם כל טעינה שלו.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final zstd = openZstdForTests();
  // ה-worker טוען את libzstd בשם הבנייה; ב-Windows זה המודול שכבר נטען.
  final workerDecodes = zstd != null && _canOpenAppZstd();
  final dictionary = File(
    'test/fixtures/line_content_codec/dict.zdict',
  ).readAsBytesSync();

  late Directory tempDir;
  late int categoryId;
  final mainIsolateOpens = <String>[];

  setUpAll(() {
    LineContentCodec.openLibrary = () {
      mainIsolateOpens.add(Isolate.current.debugName ?? '?');
      return zstd ?? (throw StateError('libzstd אינו זמין'));
    };
  });

  setUp(() async {
    mainIsolateOpens.clear();
    tempDir = await Directory.systemTemp.createTemp('otzaria-codec-placement');
    final libraryPath = path.join(tempDir.path, 'library');
    await Directory(libraryPath).create(recursive: true);
    await Settings.init(cacheProvider: MemoryCacheProvider());
    AppPaths.debugOverrideDataRootPath(path.join(tempDir.path, 'data_root'));
    await UserBooksDatabaseHolder.instance.close();
    await Settings.setValue<String>(
      SettingsRepository.keyLibraryPath,
      libraryPath,
    );
    await Settings.setValue<String>(
      SettingsRepository.keyLibraryFolderName,
      '',
    );
    await Settings.setValue<String>(SettingsRepository.keyDbEffectivePath, '');

    final dbPath = path.join(libraryPath, DatabaseConstants.databaseFileName);
    categoryId = await _seedDb(dbPath);
    _compress(dbPath, dictionary, zstd);

    await SqliteDataProvider.instance.dispose();
    await SqliteDataProvider.instance.initialize();
  });

  tearDown(() async {
    DbReadWorker.disposeForTesting();
    await SqliteDataProvider.instance.dispose();
    await UserBooksDatabaseHolder.instance.close();
    AppPaths.debugOverrideDataRootPath(null);
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // ה-handle של ה-worker ב-Windows אינו משתחרר מיד; ה-temp אינו הנבדק.
    }
  });

  test('תצוגה מקדימה וטווח שורות', () async {
    final preview = await SqliteDataProvider.instance.getBookQuickPreview(
      _title,
      15,
      categoryId: categoryId,
    );
    final range = await SqliteDataProvider.instance.getBookTextRangeFromDb(
      _title,
      startLine: 2,
      endLine: 4,
      categoryId: categoryId,
    );
    expect(mainIsolateOpens, isEmpty);
    if (!workerDecodes) return;
    expect(preview, _lines.sublist(5, 26).join('\n'));
    expect(range?.text, _lines.sublist(2, 5).join('\n'));
  });

  test('שורות ספר-מילון (לעז)', () async {
    final lines = await loadDictionaryBookLines(_title);
    expect(mainIsolateOpens, isEmpty);
    if (workerDecodes) expect(lines, _lines);
  });

  test('השורה הגולמית לדיווח טעות', () async {
    final snapshot = await ErrorReportHelper.resolveReportSource(
      book: TextBook(title: _title, categoryId: categoryId),
      lineIndex: 3,
      content: _lines,
    );
    expect(mainIsolateOpens, isEmpty);
    if (workerDecodes) expect(snapshot?.originalLine, _lines[3]);
  });

  test('סמני חלוקה בפתיחת ספר נקראים ב-worker הקבוע', () async {
    final before = DbReadWorker.sentMessageCount;
    for (var i = 0; i < 2; i++) {
      await DatabaseLibraryProvider.instance.getInlineSectionMarksByLineIndex(
        _title,
        categoryId: categoryId,
      );
    }
    expect(DbReadWorker.sentMessageCount - before, 2);
    expect(mainIsolateOpens, isEmpty);
  });
}

bool _canOpenAppZstd() {
  try {
    openZstandardLib();
    return true;
  } catch (_) {
    return false;
  }
}

Future<int> _seedDb(String dbPath) async {
  final database = MyDatabase.withPath(dbPath);
  try {
    final repo = SeforimRepository(database);
    await repo.ensureInitialized();
    final categoryId = await repo.insertCategory(
      const migration_models.Category(title: 'שורש'),
    );
    final sourceId = await repo.insertSource('test::$_title', -1);
    final bookId = await repo.insertBook(
      migration_models.Book(
        categoryId: categoryId,
        sourceId: sourceId,
        title: _title,
        fileType: 'txt',
        totalLines: _lines.length,
      ),
    );
    await repo.insertLinesBatch([
      for (var i = 0; i < _lines.length; i++)
        migration_models.Line(bookId: bookId, lineIndex: i, content: _lines[i]),
    ]);
    await repo.updateBookTotalLines(bookId, _lines.length);
    return categoryId;
  } finally {
    database.close();
  }
}

/// הופך את המסד לדחוס: טבלת `zstd_dict`, ומסגרות במקום הטקסט כשיש libzstd.
void _compress(String dbPath, Uint8List dictionary, DynamicLibrary? zstd) {
  final db = sqlite3.sqlite3.open(dbPath);
  try {
    db.execute('CREATE TABLE zstd_dict (id INTEGER PRIMARY KEY, dict BLOB)');
    db.execute('INSERT INTO zstd_dict VALUES (1, ?)', [dictionary]);
    if (zstd == null) return;
    final table =
        db
            .select(
              "SELECT 1 FROM sqlite_master WHERE name = 'line_content'",
            )
            .isEmpty
        ? 'line'
        : 'line_content';
    for (final row in db.select('SELECT id, content FROM $table')) {
      final frame = compressWithDictionary(
        zstd,
        Uint8List.fromList(utf8.encode(row['content'] as String)),
        dictionary,
      );
      db.execute('UPDATE $table SET content = ? WHERE id = ?', [
        frame,
        row['id'],
      ]);
    }
  } finally {
    db.close();
  }
}
