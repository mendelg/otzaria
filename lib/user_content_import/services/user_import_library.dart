import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/user_content_import/models/user_import_models.dart';
import 'package:otzaria/user_content_import/repository/user_content_repository.dart';
import 'package:otzaria/user_content_import/services/user_content_importer.dart';
import 'package:otzaria/user_content_import/services/user_link_ref_resolver.dart';
import 'package:otzaria/utils/file/text_encoding.dart';

/// קובץ ייבוא ששמור בספרייה, כפי שהוא מוצג בהגדרות.
@immutable
class UserImportFile {
  final int id;

  /// שם הקובץ — הוא שקובע איך הוא מפוענח, ולכן מוצג כזהות.
  final String name;

  /// הנתיב שממנו יובא, לתצוגה בלבד; הקובץ עצמו כבר לא נדרש קיים.
  final String? originPath;
  final UserImportKind kind;

  /// קובץ מושהה נשאר בספרייה אך אינו משתתף בבנייה.
  final bool enabled;
  final DateTime importedAt;

  const UserImportFile({
    required this.id,
    required this.name,
    required this.originPath,
    required this.kind,
    required this.enabled,
    required this.importedAt,
  });
}

/// תוצאת פעולה על הספרייה: מה נבנה מחדש ואילו שגיאות עלו בדרך.
@immutable
class UserImportLibraryResult {
  final UserImportResult rebuild;
  final List<String> errors;

  const UserImportLibraryResult({
    required this.rebuild,
    this.errors = const [],
  });

  bool get ok => errors.isEmpty && rebuild.errors.isEmpty;

  List<String> get allErrors => [...errors, ...rebuild.errors];
}

/// קובצי הייבוא נשמרים על תוכנם, וכל שינוי בונה מחדש מכלל הפעילים — כך ייצוא
/// והשהיה אינם דורשים מעקב פר-שורה, והמקור יכול להימחק או לזוז.
class UserImportLibrary {
  final MyDatabase _db;

  /// תלויות פתירת-הספרים של הייבוא, ניתנות להזרקה בבדיקות בדיוק כמו
  /// ב-[UserContentImporter.importContents].
  final UserLinkRefResolver resolveRef;
  final UserLinkSourceChecker sourceExists;
  final UserLinkBookLocator locateBook;

  const UserImportLibrary(
    this._db, {
    this.resolveRef = resolveUserLinkTargetLine,
    this.sourceExists = userLinkSourceBookExists,
    this.locateBook = locateUserLinkBook,
  });

  /// כל קובצי הייבוא, החדש תחילה, בלי התוכן — הוא נשלף רק בייצוא.
  Future<List<UserImportFile>> list() async {
    final db = await _db.database;
    final rows = db.select(
      'SELECT id, name, originPath, kind, enabled, importedAt '
      'FROM user_import_file ORDER BY importedAt DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// תוכן הקובץ כפי שיובא, או null אם הוסר בינתיים.
  Future<String?> contentOf(int id) async {
    final db = await _db.database;
    final rows = db.select(
      'SELECT content FROM user_import_file WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : rows.first['content'] as String;
  }

  /// שומר ובונה מחדש; אותו שם ומקור דורס את קודמו.
  Future<UserImportLibraryResult> addFiles(Iterable<String> filePaths) async {
    final db = await _db.database;
    if (db.select('SELECT 1 FROM user_import_file LIMIT 1').isEmpty) {
      await UserContentRepository(_db).captureManualBaseline();
    }
    final errors = <String>[];
    final result = await _changeAndRebuild(() async {
      await _insertFiles(db, filePaths, errors);
    });
    return UserImportLibraryResult(
      rebuild: result.rebuild,
      errors: [...errors, ...result.errors],
    );
  }

  Future<void> _insertFiles(
    sqlite3.Database db,
    Iterable<String> filePaths,
    List<String> errors,
  ) async {
    for (final path in filePaths) {
      final file = File(path);
      final name = _baseName(path);
      if (!await file.exists()) {
        errors.add('$name: הקובץ לא נמצא');
        continue;
      }
      final kind = UserContentImporter.kindOf(name);
      if (kind == null) {
        errors.add('$name: $kUnrecognizedImportFileMessage');
        continue;
      }
      final String content;
      try {
        content = await readTextFileSmart(file);
      } catch (e) {
        errors.add('$name: קריאת הקובץ נכשלה ($e)');
        continue;
      }
      db.execute(
        'INSERT INTO user_import_file '
        '(name, originPath, kind, content, enabled, importedAt) '
        'VALUES (?, ?, ?, ?, 1, ?) '
        'ON CONFLICT(name, originPath) DO UPDATE SET '
        'kind = excluded.kind, content = excluded.content, '
        'enabled = 1, importedAt = excluded.importedAt',
        [name, path, kind.name, content, DateTime.now().millisecondsSinceEpoch],
      );
    }
  }

  /// ⚠️ שינוי שהבנייה אחריו נכשלה מוחזר לאחור, אחרת קובץ אחד שאינו נקלט
  /// היה חוסם מעתה את הבנייה האטומית של כל הקבצים.
  Future<UserImportLibraryResult> _changeAndRebuild(
    Future<void> Function() change,
  ) async {
    final snapshot = await _snapshotRows();
    await change();
    final UserImportResult rebuild;
    try {
      rebuild = await rebuildFromEnabled();
    } catch (_) {
      await _restoreRows(snapshot);
      rethrow;
    }
    if (rebuild.errors.isEmpty) {
      return UserImportLibraryResult(rebuild: rebuild);
    }
    // בנייה עם שגיאות לא כתבה דבר, ולכן מספיק להחזיר את הספרייה עצמה.
    await _restoreRows(snapshot);
    return UserImportLibraryResult(
      rebuild: const UserImportResult(),
      errors: rebuild.errors,
    );
  }

  /// מצב הספרייה כפי שהוא, להחזרה אם הייבוא ייכשל.
  Future<List<Map<String, Object?>>> _snapshotRows() async {
    final db = await _db.database;
    return [for (final row in db.select('SELECT * FROM user_import_file')) row];
  }

  /// מחזיר את הספרייה למצב שב-[snapshot], על מזהיה — כך ששורה שהוחלפה
  /// בייבוא הכושל חוזרת לתוכנה הקודם ולא מקבלת זהות חדשה בממשק.
  Future<void> _restoreRows(List<Map<String, Object?>> snapshot) async {
    final db = await _db.database;
    db.execute('SAVEPOINT restore_import_files');
    db.execute('DELETE FROM user_import_file');
    for (final row in snapshot) {
      db.execute(
        'INSERT INTO user_import_file '
        '(id, name, originPath, kind, content, enabled, importedAt) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          row['id'],
          row['name'],
          row['originPath'],
          row['kind'],
          row['content'],
          row['enabled'],
          row['importedAt'],
        ],
      );
    }
    db.execute('RELEASE restore_import_files');
  }

  /// משהה או מחזיר קובץ. השהיה אינה מוחקת אותו — התוכן נשאר לייצוא ולהחזרה.
  Future<UserImportLibraryResult> setEnabled(int id, bool enabled) async {
    final db = await _db.database;
    return _changeAndRebuild(() async {
      db.execute('UPDATE user_import_file SET enabled = ? WHERE id = ?', [
        enabled ? 1 : 0,
        id,
      ]);
    });
  }

  /// מסיר קובץ מהספרייה לצמיתות, והנתונים שלו יורדים איתו בבנייה מחדש.
  Future<UserImportLibraryResult> remove(int id) async {
    final db = await _db.database;
    return _changeAndRebuild(() async {
      db.execute('DELETE FROM user_import_file WHERE id = ?', [id]);
    });
  }

  /// מסיר את כל הקבצים ומנקה את כל הנתונים הידניים, גם אלה שקדמו לספרייה.
  Future<UserImportLibraryResult> removeAll() async {
    final db = await _db.database;
    return _changeAndRebuild(() async {
      db.execute('DELETE FROM user_import_file');
      await UserContentRepository(_db).dropManualBaseline();
    });
  }

  /// בונה מחדש מהבסיס ומכל הקבצים הפעילים, בטרנזקציה אחת. ⚠️ הניקוי מוזרק
  /// לתוך הייבוא: ניקוי מוקדם היה מוחק הכול כשקובץ פגום חוסם את הייבוא האטומי.
  Future<UserImportResult> rebuildFromEnabled() async {
    final db = await _db.database;
    final repo = UserContentRepository(_db);
    Future<void> reset() async {
      await repo.clearAllUserContent();
      await repo.restoreManualBaseline();
    }

    final files = [
      for (final row in db.select(
        'SELECT name, content FROM user_import_file WHERE enabled = 1 '
        'ORDER BY id',
      ))
        ImportedFile(
          name: row['name'] as String,
          content: row['content'] as String,
        ),
    ];
    db.execute('SAVEPOINT rebuild_user_content');
    try {
      final UserImportResult result;
      if (files.isEmpty) {
        await reset();
        result = const UserImportResult();
      } else {
        result = await UserContentImporter.importContents(
          files,
          _db,
          resolveRef: resolveRef,
          sourceExists: sourceExists,
          locateBook: locateBook,
          beforeApply: reset,
        );
      }
      db.execute('RELEASE rebuild_user_content');
      return result;
    } catch (_) {
      db.execute('ROLLBACK TO rebuild_user_content');
      db.execute('RELEASE rebuild_user_content');
      rethrow;
    }
  }

  static UserImportFile _fromRow(Map<String, Object?> row) => UserImportFile(
    id: row['id'] as int,
    name: row['name'] as String,
    originPath: row['originPath'] as String?,
    kind: UserImportKind.values.firstWhere(
      (k) => k.name == row['kind'],
      orElse: () => UserImportKind.links,
    ),
    enabled: (row['enabled'] as int? ?? 1) == 1,
    importedAt: DateTime.fromMillisecondsSinceEpoch(
      row['importedAt'] as int? ?? 0,
    ),
  );

  static String _baseName(String path) =>
      path.replaceAll('\\', '/').split('/').last;
}
