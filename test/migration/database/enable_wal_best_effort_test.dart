import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:otzaria/migration/database/sqlite3_utils.dart';
import 'package:sqlite3/sqlite3.dart';

/// DB שמתעד כל `execute` ונכשל בשגיאת IO על המשפטים ש-[failOn] מזהה.
class _FakeDatabase implements Database {
  _FakeDatabase({required this.failOn, required this.extendedResultCode});

  final bool Function(String sql) failOn;
  final int extendedResultCode;
  final List<String> statements = [];

  @override
  void execute(String sql, [List<Object?> parameters = const []]) {
    statements.add(sql);
    if (failOn(sql)) {
      throw SqliteException(
        extendedResultCode: extendedResultCode,
        message: 'disk I/O error',
        causingStatement: sql,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// חיבור אמיתי שנכשל ב-BEGIN כמו WAL שאינו שמיש (IOERR_SHMOPEN).
class _ShmFailingDatabase implements Database {
  _ShmFailingDatabase(this.inner);

  final Database inner;

  @override
  void execute(String sql, [List<Object?> parameters = const []]) {
    if (sql.startsWith('BEGIN')) {
      throw SqliteException(
        extendedResultCode: 4618,
        message: 'disk I/O error',
        causingStatement: sql,
      );
    }
    inner.execute(sql, parameters);
  }

  @override
  ResultSet select(String sql, [List<Object?> parameters = const []]) =>
      inner.select(sql, parameters);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

int _synchronous(Database db) =>
    db.select('PRAGMA synchronous').first.values.first as int;

void main() {
  test('WAL מופעל על קובץ תקין', () {
    final dir = Directory.systemTemp.createTempSync('plugins_host_wal');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = sqlite3.open(p.join(dir.path, 'plugins_host.db'));
    addTearDown(db.close);

    enableWalBestEffort(db, 'test');

    expect(db.select('PRAGMA journal_mode').first.values.first, 'wal');
    expect(_synchronous(db), 1, reason: 'NORMAL');
  });

  test('openWritableDatabase: WAL עם synchronous=NORMAL ו-busy_timeout', () {
    final dir = Directory.systemTemp.createTempSync('writable_sync');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = openWritableDatabase(p.join(dir.path, 'notes.db'), 'test');
    addTearDown(db.close);

    expect(db.select('PRAGMA journal_mode').first.values.first, 'wal');
    expect(db.select('PRAGMA synchronous').first.values.first, 1);
    expect(db.select('PRAGMA busy_timeout').first.values.first, 5000);
  });

  test('בלי WAL (מסד בזיכרון) synchronous נשאר FULL', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);

    enableWalBestEffort(db, 'test');

    expect(db.select('PRAGMA journal_mode').first.values.first, 'memory');
    expect(_synchronous(db), 2, reason: 'FULL');
  });

  test('החזרה ל-journal רגיל משאירה synchronous=FULL', () {
    final dir = Directory.systemTemp.createTempSync('wal_fallback_sync');
    addTearDown(() => dir.deleteSync(recursive: true));
    final inner = sqlite3.open(p.join(dir.path, 'cache.db'));
    addTearDown(inner.close);

    enableWalBestEffort(_ShmFailingDatabase(inner), 'test');

    expect(inner.select('PRAGMA journal_mode').first.values.first, 'delete');
    expect(_synchronous(inner), 2, reason: 'FULL');
  });

  test('closeWithCheckpoint ממזג את ה-WAL גם כשחיבור אחר פתוח', () {
    final dir = Directory.systemTemp.createTempSync('close_checkpoint');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'personal_notes.db');
    final db = sqlite3.open(path);
    enableWalBestEffort(db, 'test');
    db.execute('CREATE TABLE t(x INTEGER)');
    db.execute('INSERT INTO t VALUES (1)');
    // חיבור של חלון מוסתר: בזכותו הסגירה אינה האחרונה.
    final other = sqlite3.open(path)..select('SELECT 1');
    addTearDown(other.close);

    closeWithCheckpoint(db);

    final wal = File('$path-wal');
    expect(!wal.existsSync() || wal.lengthSync() == 0, isTrue);
  });

  test('כשל בקטימת ה-journal אינו מפיל את פתיחת ה-DB', () {
    // SQLITE_IOERR_TRUNCATE (1546) — נעילה שנשארה על קובץ ה-journal.
    final db = _FakeDatabase(
      failOn: (sql) => sql.contains('journal_mode=WAL'),
      extendedResultCode: 1546,
    );

    expect(() => enableWalBestEffort(db, 'test'), returnsNormally);
  });

  test('WAL שאינו שמיש במערכת הקבצים מוחזר ל-journal רגיל', () {
    // SQLITE_IOERR_SHMOPEN (4618) — כרטיס SD ב-Android: ה-PRAGMA עובר,
    // ופתיחת ה-shared-memory נכשלת רק בטרנזקציה הראשונה.
    final db = _FakeDatabase(
      failOn: (sql) => sql.startsWith('BEGIN'),
      extendedResultCode: 4618,
    );

    expect(() => enableWalBestEffort(db, 'test'), returnsNormally);
    expect(db.statements, contains('PRAGMA journal_mode=DELETE'));
    expect(db.statements, contains('PRAGMA locking_mode=NORMAL'));
    expect(db.statements, isNot(contains('PRAGMA synchronous=NORMAL')));
  });
}
