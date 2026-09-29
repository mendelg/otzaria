import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:otzaria/data/data_providers/db_read_worker.dart';
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/migration/database/untrusted_database.dart';

const _contentBlobSql =
    'SELECT CAST(content AS BLOB) FROM line WHERE bookId = ? ORDER BY lineIndex';
const _contentTextSql =
    'SELECT content FROM line WHERE bookId = ? ORDER BY lineIndex';

final Uint8List _newline = Uint8List.fromList(const [0x0A]);

/// קריאת תוכן ספר שלם (כל שורות `line`, מאוחות ב-`\n`) מחוץ ל-UI isolate:
/// seforim.db דרך [DbReadWorker], מסד מצורף ב-isolate חד-פעמי.
class BookTextReader {
  BookTextReader._();

  /// קריאות על החיבור הראשי — רק user_books.db, שנכתב על אותו חיבור.
  @visibleForTesting
  static int mainConnectionReads = 0;

  /// הטקסט המלא של [bookId], או null כשאין לו שורות.
  static Future<String?> text(SeforimRepository repository, int bookId) =>
      _load(
        repository,
        bookId,
        workerMethod: 'bookText',
        fromWorker: (result) => result as String?,
        read: readBookContentText,
      );

  /// כמו [text], כבייטים גולמיים (UTF-8 כפי שמאוחסן) — מסלול האינדוקס.
  static Future<Uint8List?> bytes(SeforimRepository repository, int bookId) =>
      _load(
        repository,
        bookId,
        workerMethod: 'bookTextBytes',
        fromWorker: (result) =>
            (result as TransferableTypedData?)?.materialize().asUint8List(),
        read: readBookContentBytes,
      );

  static Future<T?> _load<T>(
    SeforimRepository repository,
    int bookId, {
    required String workerMethod,
    required T? Function(Object? result) fromWorker,
    required T? Function(sqlite3.Database db, int bookId) read,
  }) async {
    final database = repository.database;
    if (database.isOfficial) {
      try {
        return fromWorker(
          await DbReadWorker.request(workerMethod, {
            'dbPath': database.path,
            'bookId': bookId,
          }),
        );
      } on DbReadWorkerUnavailable {
        return DbReadWorker.runOnFreshIsolate(
          _readOnTargetTask(database.readOnlyTarget, bookId, read),
        );
      }
    }
    if (database.isUntrusted) {
      return Isolate.run(
        _readOnTargetTask(database.readOnlyTarget, bookId, read),
      );
    }
    mainConnectionReads++;
    return read(await database.database, bookId);
  }
}

// פונקציה נפרדת: סגירה בתוך _load הייתה לוכדת את ה-repository, שאינו נשלח.
T? Function() _readOnTargetTask<T>(
  ReadOnlyDbTarget target,
  int bookId,
  T? Function(sqlite3.Database db, int bookId) read,
) => () {
  final db = openReadOnlyTarget(target);
  try {
    return read(db, bookId);
  } finally {
    db.close();
  }
};

/// שורות [bookId] כבייטים בסדר השורות; תוכן NULL נקרא כשורה ריקה.
List<Uint8List> _readContentParts(
  sqlite3.Database db,
  int bookId, {
  bool stripRowBom = false,
}) {
  final statement = db.prepare(_contentBlobSql);
  try {
    final raw = statement.raw..bindInt64(1, bookId);
    final parts = <Uint8List>[];
    while (raw.step()) {
      final part = raw.columnBlob(0);
      // utf8.decode משמיט BOM בתחילת כל שורה; בחוצץ אחד — רק בשורה הראשונה.
      parts.add(
        stripRowBom && parts.isNotEmpty && _startsWithBom(part)
            ? Uint8List.sublistView(part, 3)
            : part,
      );
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

/// תוכן [bookId] כבייטים מאוחים ב-`\n`, או null כשאין לו שורות.
Uint8List? readBookContentBytes(sqlite3.Database db, int bookId) {
  final parts = _readContentParts(db, bookId);
  return parts.isEmpty ? null : _joinLines(parts);
}

/// כמו [readBookContentBytes], כחוצץ שעובר ל-isolate אחר בלי העתקה נוספת.
TransferableTypedData? readBookContentTransferable(
  sqlite3.Database db,
  int bookId,
) {
  final parts = _readContentParts(db, bookId);
  if (parts.isEmpty) return null;
  return TransferableTypedData.fromList([
    for (var i = 0; i < parts.length; i++) ...[if (i > 0) _newline, parts[i]],
  ]);
}

/// הטקסט המלא של [bookId] — זהה ל-`join('\n')` של תוכן השורות.
String? readBookContentText(sqlite3.Database db, int bookId) {
  // CAST AS BLOB מחזיר את קידוד המסד; פענוח חוצץ אחד נכון רק ב-UTF-8.
  final encoding = db.select('PRAGMA encoding').first.values.first;
  if (encoding != 'UTF-8') {
    final rows = db.select(_contentTextSql, [bookId]);
    if (rows.isEmpty) return null;
    return rows.map((row) => (row.values.first as String?) ?? '').join('\n');
  }
  final parts = _readContentParts(db, bookId, stripRowBom: true);
  return parts.isEmpty ? null : utf8.decode(_joinLines(parts));
}
