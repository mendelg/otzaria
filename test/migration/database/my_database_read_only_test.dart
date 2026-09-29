import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// בדיקות למצב read-only של [MyDatabase] — הבסיס למעבר seforim.db ל-RO.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('my-database-ro-');
    dbPath = path.join(tempDir.path, 'test.db');

    // אכלוס ראשוני בחיבור כתיב.
    final writable = MyDatabase.withPath(dbPath);
    final db = await writable.database;
    db.execute(
      "INSERT INTO category (title, level) VALUES ('בדיקה', 0)",
    );
    writable.close();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ברירת המחדל היא חיבור כתיב (isReadOnly == false)', () {
    final db = MyDatabase.withPath(dbPath);
    addTearDown(db.close);
    expect(db.isReadOnly, isFalse);
  });

  test(
    'repository כתיב (cache.db/user_books.db): WAL עם synchronous=NORMAL',
    () async {
      final database = MyDatabase.withPath(dbPath);
      addTearDown(database.close);
      await SeforimRepository(database).ensureInitialized();

      final db = await database.database;
      expect(db.select('PRAGMA journal_mode').first.values.first, 'wal');
      expect(db.select('PRAGMA synchronous').first.values.first, 1);
    },
  );

  test('readOnly: true פותח חיבור שמסומן read-only', () {
    final db = MyDatabase.withPath(dbPath, readOnly: true);
    addTearDown(db.close);
    expect(db.isReadOnly, isTrue);
  });

  test('חיבור read-only מאפשר קריאה', () async {
    final roDatabase = MyDatabase.withPath(dbPath, readOnly: true);
    addTearDown(roDatabase.close);

    final db = await roDatabase.database;
    final rows = db.select('SELECT title FROM category');
    expect(rows, hasLength(1));
    expect(rows.first['title'], 'בדיקה');
  });

  test('חיבור read-only חוסם כתיבה (query_only)', () async {
    final roDatabase = MyDatabase.withPath(dbPath, readOnly: true);
    addTearDown(roDatabase.close);

    final db = await roDatabase.database;
    expect(
      () => db.execute("INSERT INTO category (title, level) VALUES ('x', 0)"),
      throwsA(isA<SqliteException>()),
    );
  });

  test('חיבור read-only אינו יוצר קובצי WAL צדדיים', () async {
    final roDatabase = MyDatabase.withPath(dbPath, readOnly: true);
    addTearDown(roDatabase.close);

    await roDatabase.database;

    expect(await File('$dbPath-wal').exists(), isFalse);
    expect(await File('$dbPath-shm').exists(), isFalse);
  });
}
