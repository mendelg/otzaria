import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/data/data_providers/link_visibility_sql.dart';
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:otzaria/migration/database/db_capabilities.dart';
import 'package:otzaria/migration/database/query_loader.dart';
import 'package:otzaria/migration/database/untrusted_database.dart';
import 'package:path/path.dart' as path;

const _baseBook = 1;
const _commentaryA = 2;
const _commentaryB = 3;
const _otherBook = 4;
const _linesPerBook = 40;

int _lineId(int bookId, int lineIndex) => bookId * 1000 + lineIndex;

/// מסד עם הסכמה והאינדקסים של seforim.db, בלי sqlite_stat1 (כמו המסד החי).
void _buildFixture(sqlite3.Database db) {
  db.execute('''
    CREATE TABLE book (id INTEGER PRIMARY KEY, title TEXT, categoryId INTEGER,
      fileType TEXT, orderIndex INTEGER);
    CREATE TABLE line (id INTEGER PRIMARY KEY, bookId INTEGER NOT NULL,
      lineIndex INTEGER NOT NULL, heRef TEXT);
    CREATE INDEX idx_line_book_index ON line(bookId, lineIndex);
    CREATE TABLE connection_type (id INTEGER PRIMARY KEY, name TEXT);
    CREATE TABLE link (id INTEGER PRIMARY KEY, sourceBookId INTEGER NOT NULL,
      targetBookId INTEGER NOT NULL, sourceLineId INTEGER NOT NULL,
      targetLineId INTEGER NOT NULL, connectionTypeId INTEGER NOT NULL);
    CREATE INDEX idx_link_source_book ON link(sourceBookId);
    CREATE INDEX idx_link_source_line ON link(sourceLineId);
    CREATE INDEX idx_link_target_book ON link(targetBookId);
    CREATE INDEX idx_link_target_line ON link(targetLineId);
    CREATE INDEX idx_link_type ON link(connectionTypeId);
    CREATE INDEX idx_link_type_source_line ON link(connectionTypeId, sourceLineId);
    CREATE TABLE link_anchor (linkId INTEGER, side INTEGER, charStart INTEGER,
      charEnd INTEGER, label TEXT, PRIMARY KEY (linkId, side, charStart));
    CREATE TABLE link_range (linkId INTEGER, side INTEGER, endLineId INTEGER,
      endLineIndex INTEGER, PRIMARY KEY (linkId, side));
    CREATE TABLE link_coverage (lineId INTEGER, linkId INTEGER, side INTEGER,
      PRIMARY KEY (lineId, linkId, side));
    CREATE TABLE link_suppressed_side (linkId INTEGER NOT NULL,
      side INTEGER NOT NULL, reasonMask INTEGER NOT NULL,
      PRIMARY KEY (linkId, side));
    CREATE TABLE author (id INTEGER PRIMARY KEY, name TEXT);
    CREATE TABLE book_author (bookId INTEGER, authorId INTEGER);
  ''');
  final books = {
    _baseBook: 'base',
    _commentaryA: 'commentary-a',
    _commentaryB: 'commentary-b',
    _otherBook: 'other',
  };
  for (final MapEntry(key: id, value: title) in books.entries) {
    db.execute('INSERT INTO book VALUES (?, ?, 7, ?, ?)', [
      id,
      title,
      'txt',
      id,
    ]);
    for (var i = 0; i < _linesPerBook; i++) {
      db.execute('INSERT INTO line VALUES (?, ?, ?, ?)', [
        _lineId(id, i),
        id,
        i,
        '$title $i',
      ]);
    }
  }
  db.execute("INSERT INTO author VALUES (1, 'author-a')");
  db.execute('INSERT INTO book_author VALUES (?, 1)', [_commentaryA]);
  db.execute('''
    INSERT INTO connection_type VALUES
      (1, 'COMMENTARY'), (2, 'TARGUM'), (3, 'REFERENCE'), (4, 'QUOTATION')
  ''');

  var linkId = 0;
  var seed = 17;
  int next(int bound) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed % bound;
  }

  void link(int sb, int si, int tb, int ti, int type) {
    linkId++;
    db.execute('INSERT INTO link VALUES (?, ?, ?, ?, ?, ?)', [
      linkId,
      sb,
      tb,
      _lineId(sb, si),
      _lineId(tb, ti),
      type,
    ]);
    if (next(4) == 0) {
      db.execute('INSERT INTO link_anchor VALUES (?, ?, ?, ?, ?)', [
        linkId,
        next(2),
        next(20),
        20 + next(20),
        'l$linkId',
      ]);
    }
    if (next(9) == 0) {
      db.execute('INSERT INTO link_suppressed_side VALUES (?, ?, 1)', [
        linkId,
        next(2),
      ]);
    }
  }

  // השורות הגבוהות של ספר הבסיס נשארות בלי קישור, כדי שהמקסימום יהיה נמוך מהסוף.
  for (var i = 0; i < _linesPerBook - 6; i++) {
    link(_baseBook, i, _commentaryA, next(_linesPerBook), 1 + next(2));
    if (next(2) == 0) {
      link(_baseBook, i, _commentaryB, next(_linesPerBook), 1);
    }
    link(_otherBook, next(_linesPerBook), _baseBook, i, 3 + next(2));
  }
  // הפניות בתוך אותו ספר, וקישור-טווח שמכסה שורות בספר המפרש (side=1).
  link(_commentaryA, 3, _commentaryA, 9, 3);
  link(_commentaryA, 12, _commentaryA, 12, 3);
  link(_baseBook, 5, _commentaryA, 20, 1);
  db.execute('INSERT INTO link_range VALUES (?, 1, ?, 23)', [
    linkId,
    _lineId(_commentaryA, 23),
  ]);
  for (var i = 21; i <= 23; i++) {
    db.execute('INSERT INTO link_coverage VALUES (?, ?, 1)', [
      _lineId(_commentaryA, i),
      linkId,
    ]);
  }
}

/// העמודות שרק חלק מהשאילתות בוחרות (מזהי שורות, provenance) אינן בהשוואה.
List<String> _canonical(Iterable<Map<String, dynamic>> rows) =>
    rows
        .map(
          (row) => jsonEncode({
            for (final e in row.entries)
              if (!const {
                'sourceLineId',
                'targetLineId',
                'baseProvenance',
              }.contains(e.key))
                e.key: e.value,
          }),
        )
        .toList()
      ..sort();

String _plan(sqlite3.Database db, String sql, List<Object?> params) => db
    .select('EXPLAIN QUERY PLAN $sql', params)
    .map((r) => r['detail'])
    .join('\n');

const _oldCommentatorsByLineRange = '''
SELECT l.targetBookId, b.title AS targetBookTitle, a.name AS author,
       COUNT(*) AS linkCount, MIN(tl.lineIndex) AS targetLineIndex
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
JOIN book b ON l.targetBookId = b.id
JOIN line sl ON l.sourceLineId = sl.id
JOIN line tl ON l.targetLineId = tl.id
LEFT JOIN book_author ba ON b.id = ba.bookId
LEFT JOIN author a ON ba.authorId = a.id
WHERE l.sourceBookId = ?
AND ct.name IN ('COMMENTARY', 'SUPER_COMMENTARY', 'TARGUM', 'MIDRASH', 'PARSHANUT', 'DIBUR_HAMATCHIL', 'ELUCIDATION', 'FOOTNOTES')
AND sl.lineIndex >= ?
AND sl.lineIndex < ?
AND NOT EXISTS (SELECT 1 FROM link_suppressed_side ss WHERE ss.linkId = l.id AND ss.side = 0)
GROUP BY l.targetBookId, b.title, a.name
ORDER BY b.orderIndex, b.title''';

const _oldCommentaryLinksByLineRange = '''
SELECT l.targetBookId, b.title AS targetBookTitle,
       b.categoryId AS targetCategoryId, NULL AS targetFileType,
       MIN(ct.name) AS connectionType,
       MIN(tl.lineIndex) AS minTargetLineIndex,
       MAX(tl.lineIndex) AS maxTargetLineIndex,
       MIN(CASE WHEN sl.lineIndex = ? THEN tl.lineIndex END) AS exactTargetLineIndex
FROM link l
JOIN connection_type ct ON l.connectionTypeId = ct.id
JOIN book b ON l.targetBookId = b.id
JOIN line sl ON l.sourceLineId = sl.id
JOIN line tl ON l.targetLineId = tl.id
WHERE l.sourceBookId = ?
AND ct.name IN ('COMMENTARY', 'SUPER_COMMENTARY', 'TARGUM', 'MIDRASH', 'PARSHANUT', 'DIBUR_HAMATCHIL', 'FOOTNOTES')
AND sl.lineIndex >= ?
AND sl.lineIndex < ?
AND l.targetBookId != ?
AND NOT EXISTS (SELECT 1 FROM link_suppressed_side ss WHERE ss.linkId = l.id AND ss.side = 0)
GROUP BY l.targetBookId, b.title, b.categoryId
ORDER BY b.orderIndex, b.title''';

String _breadcrumbSql(String join) =>
    'WITH RECURSIVE chain(id, parentId, textId, level) AS ('
    '  SELECT te.id, te.parentId, te.textId, te.level '
    '  FROM line l '
    '  JOIN line_toc lt ON lt.lineId = l.id '
    '  JOIN tocEntry te ON te.id = lt.tocEntryId '
    '  WHERE l.bookId = ? AND l.lineIndex = ? '
    '  UNION ALL '
    '  SELECT te.id, te.parentId, te.textId, te.level '
    '  FROM tocEntry te JOIN chain c ON te.id = c.parentId'
    ') '
    'SELECT t.text FROM chain c $join tocText t ON t.id = c.textId '
    'WHERE c.level > 0 ORDER BY c.level';

/// ספר אחד עם עץ כותרות בשלוש רמות, בתוך tocText גדול משל ספרים אחרים.
void _buildTocFixture(sqlite3.Database db) {
  db.execute('''
    CREATE TABLE line (id INTEGER PRIMARY KEY, bookId INTEGER NOT NULL,
      lineIndex INTEGER NOT NULL);
    CREATE INDEX idx_line_book_index ON line(bookId, lineIndex);
    CREATE TABLE tocText (id INTEGER PRIMARY KEY, text TEXT NOT NULL UNIQUE);
    CREATE INDEX idx_toc_text ON tocText(text);
    CREATE TABLE tocEntry (id INTEGER PRIMARY KEY, bookId INTEGER NOT NULL,
      parentId INTEGER, textId INTEGER NOT NULL, level INTEGER NOT NULL);
    CREATE INDEX idx_toc_book ON tocEntry(bookId);
    CREATE TABLE line_toc (lineId INTEGER PRIMARY KEY,
      tocEntryId INTEGER NOT NULL);
    CREATE INDEX idx_linetoc_toc ON line_toc(tocEntryId);
  ''');
  for (var i = 1; i <= 500; i++) {
    db.execute('INSERT INTO tocText VALUES (?, ?)', [i, 'toc $i']);
  }
  db.execute('INSERT INTO tocEntry VALUES (1, 1, NULL, 400, 0)');
  var entryId = 1;
  for (var chapter = 0; chapter < 4; chapter++) {
    final chapterId = ++entryId;
    db.execute('INSERT INTO tocEntry VALUES (?, 1, 1, ?, 1)', [
      chapterId,
      10 + chapter,
    ]);
    for (var section = 0; section < 3; section++) {
      final sectionId = ++entryId;
      db.execute('INSERT INTO tocEntry VALUES (?, 1, ?, ?, 2)', [
        sectionId,
        chapterId,
        100 + chapter * 3 + section,
      ]);
      for (var k = 0; k < 2; k++) {
        final lineIndex = (chapter * 3 + section) * 2 + k;
        db.execute('INSERT INTO line VALUES (?, 1, ?)', [
          lineIndex + 1,
          lineIndex,
        ]);
        db.execute('INSERT INTO line_toc VALUES (?, ?)', [
          lineIndex + 1,
          k == 0 ? sectionId : chapterId,
        ]);
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;
  late sqlite3.Database db;

  setUpAll(() async {
    await QueryLoader.initialize();
    tempDir = await Directory.systemTemp.createTemp('link_range_queries');
    dbPath = path.join(tempDir.path, 'seforim.db');
    db = sqlite3.sqlite3.open(dbPath);
    _buildFixture(db);
  });

  tearDownAll(() async {
    db.close();
    await tempDir.delete(recursive: true);
  });

  String linkQuery(String name) {
    final capabilities = DbCapabilities.probe(db);
    return capabilities
        .adaptBookQuery(QueryLoader.loadQueries('LinkQueries.sq')[name]!)
        .replaceFirst(
          linkVisibilityFilterMarker,
          suppressedSideFilter(true, displayedSide: 0),
        );
  }

  const windows = [(0, 0), (0, 9), (3, 17), (18, 25), (30, 39), (0, 39)];

  test('חלון המקור ההפוך זהה לטעינת כל הספר המסוננת לחלון', () {
    for (final title in ['commentary-a', 'commentary-b', 'base']) {
      final all = DatabaseLibraryProvider.loadBookLinksRowsForTesting(
        dbPath: dbPath,
        title: title,
        categoryId: 7,
        fileType: 'txt',
      );
      for (final (start, end) in windows) {
        final ranged =
            DatabaseLibraryProvider.loadBookLinksRowsInRangeForTesting(
              dbPath: dbPath,
              title: title,
              categoryId: 7,
              fileType: 'txt',
              startLineIndex: start,
              endLineIndex: end,
            );
        final expected = all.where((r) {
          final index = r['sourceLineIndex'] as int;
          return index >= start && index <= end;
        });
        expect(
          _canonical(ranged),
          _canonical(expected),
          reason: '$title [$start, $end]',
        );
      }
    }
  });

  test('שאילתות המפרשים לטווח זהות לגרסה הקודמת ולא נשענות על ספר המקור', () {
    final commentators = linkQuery('selectCommentatorsByLineRange');
    final commentaryLinks = linkQuery('selectCommentaryLinksByLineRange');
    for (final (start, end) in windows) {
      final exact = start + 1;
      final rangeParams = [_baseBook, start, end + 1];
      final linkParams = [exact, _baseBook, start, end + 1, _commentaryB];
      final newCommentators = db.select(commentators, rangeParams);
      expect(newCommentators, isNotEmpty);
      expect(
        _canonical(newCommentators),
        _canonical(db.select(_oldCommentatorsByLineRange, rangeParams)),
      );
      expect(
        _canonical(db.select(commentaryLinks, linkParams)),
        _canonical(db.select(_oldCommentaryLinksByLineRange, linkParams)),
      );
    }

    // בלי sqlite_stat1 הנוסח הישן בוחר ב-idx_link_source_book — הסיבה לשינוי.
    expect(
      _plan(db, _oldCommentatorsByLineRange, [_baseBook, 0, 10]),
      contains('idx_link_source_book'),
    );
    for (final (sql, params) in [
      (commentators, [_baseBook, 0, 10]),
      (commentaryLinks, [1, _baseBook, 0, 10, _commentaryB]),
    ]) {
      final plan = _plan(db, sql, params);
      expect(plan, isNot(contains('idx_link_source_book')));
      expect(plan, contains('idx_line_book_index'));
      expect(plan, contains('idx_link_source_line'));
    }
  });

  test('השורה המקושרת הגבוהה בסיכום זהה ל-MAX על קישורי הספר', () {
    for (final (bookId, title) in [
      (_baseBook, 'base'),
      (_commentaryA, 'commentary-a'),
      (_commentaryB, 'commentary-b'),
    ]) {
      final expected = db.select(
        'SELECT MAX(sl.lineIndex) AS m FROM link l '
        'JOIN line sl ON sl.id = l.sourceLineId WHERE l.sourceBookId = ?',
        [bookId],
      ).first['m'];
      final summary =
          DatabaseLibraryProvider.loadBookLinkTargetsSummaryRowsForTesting(
            dbPath: dbPath,
            title: title,
            categoryId: 7,
          );
      expect(summary.maxSourceLineIndex, expected, reason: title);
    }
    final base =
        DatabaseLibraryProvider.loadBookLinkTargetsSummaryRowsForTesting(
          dbPath: dbPath,
          title: 'base',
          categoryId: 7,
        );
    expect(base.maxSourceLineIndex, lessThan(_linesPerBook - 1));
  });

  test('חיבור read-only מהימן מכוונן; מצורף נשאר בלי mmap', () {
    int pragma(sqlite3.Database conn, String name) =>
        conn.select('PRAGMA $name').first.values.first as int;

    final trusted = openReadOnlyTarget(trustedDbTarget(dbPath));
    try {
      expect(pragma(trusted, 'query_only'), 1);
      expect(pragma(trusted, 'temp_store'), 2);
      expect(pragma(trusted, 'mmap_size'), 67108864);
    } finally {
      trusted.close();
    }
    final attached = openReadOnlyTarget((
      path: dbPath,
      untrusted: true,
      immutable: false,
    ));
    try {
      expect(pragma(attached, 'query_only'), 1);
      expect(pragma(attached, 'mmap_size'), 0);
    } finally {
      attached.close();
    }
  });

  test('שביל הכותרות של שורה זהה לנוסח הקודם, עם sqlite_stat1 ובלעדיה', () {
    final tocDb = sqlite3.sqlite3.openInMemory();
    try {
      _buildTocFixture(tocDb);
      final oldSql = _breadcrumbSql('JOIN');
      final newSql = _breadcrumbSql('CROSS JOIN');
      void expectSame() {
        for (var lineIndex = 0; lineIndex < 25; lineIndex++) {
          final params = [1, lineIndex];
          expect(
            tocDb.select(newSql, params).map((r) => r['text']).toList(),
            tocDb.select(oldSql, params).map((r) => r['text']).toList(),
            reason: 'line $lineIndex',
          );
        }
      }

      expectSame();
      tocDb.execute('ANALYZE');
      expectSame();
      expect(
        _plan(tocDb, newSql, [1, 0]),
        contains('SEARCH t USING INTEGER PRIMARY KEY'),
      );
    } finally {
      tocDb.close();
    }
  });
}
