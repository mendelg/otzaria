import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';

/// ספר בפורמט אוצריא: `<h1>` יחיד בשורה 0 הוא שם הספר, כמו בספר אישי (#1901).
Future<SeforimRepository> _repoWithTitleHeading(String h1) async {
  final dir = await Directory.systemTemp.createTemp('otzaria_title_heading');
  final database = MyDatabase.withPath('${dir.path}/seforim.db');
  addTearDown(() async {
    database.close();
    await dir.delete(recursive: true);
  });
  final db = await database.database;
  db.execute("INSERT INTO category(id,title,level) VALUES(1,'ספרייה',0)");
  db.execute("INSERT INTO source(id,name) VALUES(1,'אוצריא')");
  db.execute(
    "INSERT INTO book(id,categoryId,sourceId,title,orderIndex,filePath,fileType) "
    "VALUES(1,1,1,'חידושי הרן על נדה',1,'/b.txt','txt')",
  );
  final toc = [
    (id: 1, parent: null, level: 1, text: h1, line: 0),
    (id: 2, parent: 1, level: 2, text: 'פרק א - שמאי', line: 1),
    (id: 3, parent: 2, level: 3, text: 'דף יב.', line: 2),
  ];
  for (final e in toc) {
    db.execute(
      'INSERT INTO line(id,bookId,lineIndex,content) VALUES(?,1,?,?)',
      [e.line + 1, e.line, e.text],
    );
    db.execute('INSERT INTO tocText(id,text) VALUES(?,?)', [e.id, e.text]);
    db.execute(
      'INSERT INTO tocEntry(id,bookId,parentId,textId,level,lineId) '
      'VALUES(?,1,?,?,?,?)',
      [e.id, e.parent, e.id, e.level, e.line + 1],
    );
  }
  final seforim = SeforimRepository(database);
  await seforim.ensureInitialized();
  return seforim;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('כותרת שם הספר אינה נכפלת בכתובת שאחרי שם הספר', () async {
    final seforim = await _repoWithTitleHeading('חדושי הרן על מסכת נדה');
    final toc = await seforim.getTocEntriesForReference(
      1,
      'חידושי הרן על נדה',
      queryTokens: const ['יב'],
    );
    expect(toc.map((e) => e['reference']), [
      'חידושי הרן על נדה פרק א - שמאי דף יב.',
    ]);
  });
}
