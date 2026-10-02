import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:path/path.dart' as path;

/// Callers that only need base book fields (the catalog title set, gematria)
/// use [SeforimRepository.getAllBooksLean] instead of the relation-loading
/// [SeforimRepository.getAllBooks]; both must return the same books.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MyDatabase db;
  late SeforimRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('otzaria-lean-books-');
    db = MyDatabase.withPath(path.join(tempDir.path, 'seforim.db'));
    repo = SeforimRepository(db);
    await repo.ensureInitialized();
    final raw = await db.database;
    raw.execute(
      "INSERT INTO book (id, categoryId, sourceId, title, filePath, fileType) "
      "VALUES (1, 4, 1, 'בראשית', 'תורה/בראשית.txt', 'txt'), "
      "(2, 7, 1, 'ברכות', NULL, 'pdf'), "
      "(3, 7, 1, 'שבת', NULL, NULL)",
    );
    raw.execute("INSERT INTO author (id, name) VALUES (1, 'רש\"י')");
    raw.execute('INSERT INTO book_author (bookId, authorId) VALUES (1, 1)');
  });

  tearDown(() async {
    db.close();
    await tempDir.delete(recursive: true);
  });

  test('returns the same books and base fields as getAllBooks', () async {
    String describe(dynamic b) =>
        '${b.id}|${b.title}|${b.categoryId}|${b.fileType}|${b.filePath}';

    final full = await repo.getAllBooks();
    final lean = await repo.getAllBooksLean();

    expect(lean.map(describe), full.map(describe));
    expect(full.firstWhere((b) => b.id == 1).authors, isNotEmpty);
  });
}
