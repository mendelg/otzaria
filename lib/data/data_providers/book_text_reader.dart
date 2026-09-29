import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:otzaria/data/data_providers/db_read_worker.dart';
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:otzaria/migration/models/book.dart' as db_models;
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/migration/database/untrusted_database.dart';

// הזהות נבדקת באותה שאילתה (אותו snapshot): patch שהוחל בין הפתרון על ה-UI
// לקריאה ב-worker עלול להצמיד את המזהה לספר אחר.
const _bookMatches =
    'EXISTS (SELECT 1 FROM book WHERE id = ?1 AND title = ?2 AND categoryId = ?3)';
const _contentBlobSql =
    'SELECT CAST(content AS BLOB) FROM line WHERE bookId = ?1 AND $_bookMatches '
    'ORDER BY lineIndex';
const _contentTextSql =
    'SELECT content FROM line WHERE bookId = ?1 AND $_bookMatches '
    'ORDER BY lineIndex';

/// הספר שנפתר על ה-UI isolate; קריאה שהמזהה שלה כבר אינו שלו מחזירה null.
typedef BookTextKey = ({int id, String title, int categoryId});

/// נקרא כל [_rowsPerCheckpoint] שורות; זריקה ממנו קוטעת את הקריאה.
typedef ReadCheckpoint = Future<void> Function();

const _rowsPerCheckpoint = 4096;

typedef _BookRead<T> =
    Future<T?> Function(
      sqlite3.Database db,
      BookTextKey book, {
      ReadCheckpoint? checkpoint,
    });

final Uint8List _newline = Uint8List.fromList(const [0x0A]);

/// קריאת תוכן ספר שלם (כל שורות `line`, מאוחות ב-`\n`) מחוץ ל-UI isolate:
/// seforim.db דרך [DbReadWorker], מסד מצורף ב-isolate חד-פעמי.
class BookTextReader {
  BookTextReader._();

  /// קריאות על החיבור הראשי — רק user_books.db, שנכתב על אותו חיבור.
  @visibleForTesting
  static int mainConnectionReads = 0;

  /// הטקסט המלא של [book], או null כשאין לו שורות.
  static Future<String?> text(
    SeforimRepository repository,
    db_models.Book book,
  ) => _load(
    repository,
    book,
    workerMethod: 'bookText',
    fromWorker: (result) => result as String?,
    read: readBookContentText,
  );

  /// כמו [text], כבייטים גולמיים (UTF-8 כפי שמאוחסן) — מסלול האינדוקס.
  static Future<Uint8List?> bytes(
    SeforimRepository repository,
    db_models.Book book,
  ) => _load(
    repository,
    book,
    workerMethod: 'bookTextBytes',
    fromWorker: (result) =>
        (result as TransferableTypedData?)?.materialize().asUint8List(),
    read: readBookContentBytes,
  );

  static Future<T?> _load<T>(
    SeforimRepository repository,
    db_models.Book book, {
    required String workerMethod,
    required T? Function(Object? result) fromWorker,
    required _BookRead<T> read,
  }) async {
    final BookTextKey key = (
      id: book.id,
      title: book.title,
      categoryId: book.categoryId,
    );
    final database = repository.database;
    if (database.isOfficial) {
      try {
        return fromWorker(
          await DbReadWorker.request(workerMethod, {
            'dbPath': database.path,
            'bookId': key.id,
            'title': key.title,
            'categoryId': key.categoryId,
          }),
        );
      } on DbReadWorkerUnavailable {
        return DbReadWorker.runOnFreshIsolate(
          _readOnTargetTask(database.readOnlyTarget, key, read),
        );
      }
    }
    if (database.isUntrusted) {
      return Isolate.run(_readOnTargetTask(database.readOnlyTarget, key, read));
    }
    mainConnectionReads++;
    return read(await database.database, key);
  }
}

// פונקציה נפרדת: סגירה בתוך _load הייתה לוכדת את ה-repository, שאינו נשלח.
Future<T?> Function() _readOnTargetTask<T>(
  ReadOnlyDbTarget target,
  BookTextKey book,
  _BookRead<T> read,
) => () async {
  final db = openReadOnlyTarget(target);
  try {
    return await read(db, book);
  } finally {
    db.close();
  }
};

/// שורות [book] כבייטים בסדר השורות; תוכן NULL נקרא כשורה ריקה.
Future<List<Uint8List>> _readContentParts(
  sqlite3.Database db,
  BookTextKey book, {
  bool stripRowBom = false,
  ReadCheckpoint? checkpoint,
}) async {
  final statement = db.prepare(_contentBlobSql);
  try {
    final raw = statement.raw
      ..bindInt64(1, book.id)
      ..bindText(2, book.title)
      ..bindInt64(3, book.categoryId);
    final parts = <Uint8List>[];
    while (raw.step()) {
      final part = raw.columnBlob(0);
      // utf8.decode משמיט BOM בתחילת כל שורה; בחוצץ אחד — רק בשורה הראשונה.
      parts.add(
        stripRowBom && parts.isNotEmpty && _startsWithBom(part)
            ? Uint8List.sublistView(part, 3)
            : part,
      );
      if (checkpoint != null && parts.length % _rowsPerCheckpoint == 0) {
        await checkpoint();
      }
    }
    return parts;
  } finally {
    statement.close();
  }
}

bool _startsWithBom(Uint8List part) =>
    part.length >= 3 && part[0] == 0xEF && part[1] == 0xBB && part[2] == 0xBF;

Uint8List _joinLines(List<Uint8List> parts) {
  var total = parts.length - 1;
  for (final part in parts) {
    total += part.length;
  }
  final joined = Uint8List(total);
  var offset = 0;
  for (var i = 0; i < parts.length; i++) {
    if (i > 0) joined[offset++] = 0x0A;
    joined.setAll(offset, parts[i]);
    offset += parts[i].length;
  }
  return joined;
}

/// תוכן [book] כבייטים מאוחים ב-`\n`, או null כשאין לו שורות.
Future<Uint8List?> readBookContentBytes(
  sqlite3.Database db,
  BookTextKey book, {
  ReadCheckpoint? checkpoint,
}) async {
  final parts = await _readContentParts(db, book, checkpoint: checkpoint);
  return parts.isEmpty ? null : _joinLines(parts);
}

/// כמו [readBookContentBytes], כחוצץ שעובר ל-isolate אחר בלי העתקה נוספת.
Future<TransferableTypedData?> readBookContentTransferable(
  sqlite3.Database db,
  BookTextKey book, {
  ReadCheckpoint? checkpoint,
}) async {
  final parts = await _readContentParts(db, book, checkpoint: checkpoint);
  if (parts.isEmpty) return null;
  return TransferableTypedData.fromList([
    for (var i = 0; i < parts.length; i++) ...[if (i > 0) _newline, parts[i]],
  ]);
}

/// הטקסט המלא של [book] — זהה ל-`join('\n')` של תוכן השורות.
Future<String?> readBookContentText(
  sqlite3.Database db,
  BookTextKey book, {
  ReadCheckpoint? checkpoint,
}) async {
  // CAST AS BLOB מחזיר את קידוד המסד; פענוח חוצץ אחד נכון רק ב-UTF-8.
  final encoding = db.select('PRAGMA encoding').first.values.first;
  if (encoding != 'UTF-8') {
    final rows = db.select(_contentTextSql, [
      book.id,
      book.title,
      book.categoryId,
    ]);
    if (rows.isEmpty) return null;
    return rows.map((row) => (row.values.first as String?) ?? '').join('\n');
  }
  final parts = await _readContentParts(
    db,
    book,
    stripRowBom: true,
    checkpoint: checkpoint,
  );
  return parts.isEmpty ? null : utf8.decode(_joinLines(parts));
}
