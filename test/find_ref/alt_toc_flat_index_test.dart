import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/find_ref/repository/alt_toc_flat_entry.dart';
import 'package:otzaria/find_ref/repository/find_ref_db_isolate.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/migration/models/category.dart';
import 'package:otzaria/migration/models/line.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';
import 'package:path/path.dart' as path;

/// הקאש הגלובלי של ה-AltToc: מה שנגזר מהשרשרת זהה למה שנגזר מהנתיב המלא,
/// וההתאמה המהירה זהה ל-[altTocFlatMatches] על כל ערך.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<String> tokensOf(String reference) => normalizeForFindRefMatch(
    reference,
  ).split(' ').where((t) => t.isNotEmpty).toList();

  String? dafNumberIn(List<String> tokens) {
    final at = tokens.lastIndexOf('דף');
    return at >= 0 && at + 1 < tokens.length ? tokens[at + 1] : null;
  }

  const queries = [
    ['סעיף', 'א'],
    ['סעיף'],
    ['פרק', 'א'],
    ['דף', 'יב'],
    ['דף', 'יב', 'א'],
    ['דף', 'יב', 'ב'],
    ['פרק', 'דף', 'יב'],
    ['שבת', 'דף', 'ג'],
    ['הלכות', 'שבת'],
    ['ספר', 'א', 'סימן'],
    ['ג'],
    ['אין', 'כזה'],
  ];

  void expectConsistent(AltTocFlatIndex index) {
    final references = AltTocQualifiedReferences(index);
    for (var i = 0; i < index.length; i++) {
      final reference = index.referenceOf(i);
      final tokens = index.refTokensOf(i);
      expect(tokens, tokensOf(reference), reason: reference);
      expect(index.refTokenCountOf(i), tokens.length);
      expect(index.refMasks[i], altTocTokenMask(tokens));
      expect(index.dafNumberOf(i), dafNumberIn(tokens), reason: reference);
      expect(
        references.of(i),
        qualifyAltTocReference(index.bookOf(i).title, reference),
      );
    }
    for (final q in queries) {
      for (final max in [null, 2]) {
        final dafCitation = parseDafCitationFromDafToken(q);
        expect(
          matchAltTocFlatIndex(index, q, maxRefTokens: max),
          [
            for (var i = 0; i < index.length; i++)
              if (altTocFlatMatches(
                index.refTokensOf(i),
                q,
                maxRefTokens: max,
                dafCitation: dafCitation,
              ))
                i,
          ],
          reason: '$q max=$max',
        );
      }
    }
  }

  group('קאש קטן', () {
    late Directory tempDir;
    late MyDatabase database;
    late SeforimRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('alt-toc-index-');
      database = MyDatabase.withPath(path.join(tempDir.path, 'test.db'));
      repository = SeforimRepository(database);
      await repository.ensureInitialized();
    });

    tearDown(() async {
      database.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<AltTocFlatIndex> build({int chunk = 2}) async {
      final build = repository.beginAltTocFlatIndex(
        rowsPerStep: chunk,
        textsPerStep: chunk,
        linesPerStep: chunk,
      );
      while (!await build.step()) {}
      return build.index;
    }

    /// שני ספרים: טקסט ריק באמצע שרשרת, "דף" שהמספר שלו אצל הילד, טקסט
    /// שמתחיל בשם הספר, הורה חסר, הורה שמזהה גדול משל הילד ושורה חסרה.
    Future<List<int>> seed() async {
      final categoryId = await repository.insertCategory(
        const Category(title: 'קטגוריה', parentId: null, level: 0),
      );
      Future<int> book(String title) => repository.insertExternalContentBook(
        categoryId: categoryId,
        title: title,
        filePath: '/tmp/$title.txt',
        fileType: 'txt',
        fileSize: 0,
        lastModified: 0,
        isPersonal: false,
      );
      final a = await book('ספר א');
      final b = await book('שבת');
      final lines = [
        for (var i = 0; i < 10; i++)
          await repository.insertLine(
            Line(id: 0, bookId: a, lineIndex: i, content: 'שורה $i'),
          ),
      ];
      final db = await database.database;
      db.execute(
        "INSERT INTO alt_toc_structure (id, bookId, key) VALUES (1, ?, 'a')",
        [a],
      );
      db.execute(
        "INSERT INTO alt_toc_structure (id, bookId, key) VALUES (2, ?, 'b')",
        [b],
      );
      var textId = 100;
      void entry(
        int id,
        int structure,
        String text,
        int level, {
        int? parent,
        int? line,
      }) {
        db.execute('INSERT OR IGNORE INTO tocText (id, text) VALUES (?, ?)', [
          ++textId,
          text,
        ]);
        final stored = db.select('SELECT id FROM tocText WHERE text = ?', [
          text,
        ]).first['id'];
        db.execute(
          'INSERT INTO alt_toc_entry '
          '(id, structureId, parentId, textId, level, lineId) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [id, structure, parent, stored, level, line],
        );
      }

      entry(1, 1, 'פרק א', 0, line: lines[2]);
      entry(2, 1, 'דף', 1, parent: 1);
      entry(3, 1, 'יב.', 2, parent: 2, line: lines[5]);
      entry(4, 1, 'יב:', 2, parent: 2, line: lines[6]);
      entry(5, 1, '', 1, parent: 1);
      entry(6, 1, 'סעיף ב', 2, parent: 5, line: lines[7]);
      entry(7, 1, 'ספר א סימן ג', 0, line: lines[1]);
      entry(8, 1, 'סעיף א', 1, parent: 7, line: lines[3]);
      entry(9, 1, 'הלכות שבת', 1, parent: 9999);
      entry(10, 1, 'סעיף א', 1, parent: 12, line: lines[8]);
      entry(12, 1, 'פרק ב דף יב', 0, line: 99999);
      entry(13, 2, 'דף ג', 0);
      entry(14, 2, 'א', 1, parent: 13);
      entry(15, 2, 'סעיף א', 1, parent: 13);
      return lines;
    }

    test('הנגזרות מהשרשרת זהות לנגזרות מהנתיב, וההתאמה זהה', () async {
      await seed();
      final index = await build();
      expect(index.length, 14);
      expectConsistent(index);

      final byId = {
        for (var i = 0; i < index.length; i++)
          index.flatRowOf(i)['reference']: i,
      };
      // הנתיב של ערך תחת טקסט ריק נשמר כפי שהיה — עם רווח כפול.
      expect(byId.containsKey('פרק א  סעיף ב'), isTrue);
      expect(index.parentOf(byId['הלכות שבת']!), -1);
      expect(index.referenceOf(byId['פרק ב דף יב סעיף א']!), isNotEmpty);
      expect(index.segmentOf(byId['פרק א דף יב.']!), 5);
      expect(index.segmentOf(byId['פרק ב דף יב']!), 0);
      expect(index.dafNumberOf(byId['פרק א דף יב.']!), 'יב');
      expect(index.dafNumberOf(byId['פרק א דף']!), isNull);
    });

    test('שורות צרות (JOIN) ושורות עם תוכן (אינדקס) נותנות אותו קאש', () async {
      await seed();
      List<Map<String, dynamic>> rows(AltTocFlatIndex index) => [
        for (var i = 0; i < index.length; i++) index.flatRowOf(i),
      ];
      final withContent = rows(await build());

      final db = await database.database;
      db.execute('ALTER TABLE line DROP COLUMN content');
      final narrow = rows(await build(chunk: 100));
      expect(narrow, withContent);
    });

    test('בלי ערכי AltToc הקאש ריק', () async {
      expect((await build()).length, 0);
    });
  });

  final dbPath = Platform.environment['OTZARIA_BENCH_DB'];
  test(
    'מסד אמיתי: הנגזרות וההתאמה זהות על כל הערכים',
    () async {
      final repository = SeforimRepository(
        MyDatabase.withPath(dbPath!, readOnly: true, official: true),
      );
      await repository.ensureInitialized();
      addTearDown(repository.database.close);
      final build = repository.beginAltTocFlatIndex();
      while (!await build.step()) {}
      final index = build.index;
      expect(index.length, greaterThan(0));
      for (var i = 0; i < index.length; i++) {
        final tokens = index.refTokensOf(i);
        if (tokens.length != index.refTokenCountOf(i) ||
            index.dafNumberOf(i) != dafNumberIn(tokens) ||
            !listEquals(tokens, tokensOf(index.referenceOf(i)))) {
          fail('entry $i differs');
        }
      }
      for (final q in [
        ...queries,
        ['דף', 'ב'],
        ['דף', 'ב', 'א'],
        ['דף', 'ה', 'ב'],
        ['מאימתי', 'דף', 'ב'],
        ['סעיף', 'ב'],
      ]) {
        final dafCitation = parseDafCitationFromDafToken(q);
        final expected = [
          for (var i = 0; i < index.length; i++)
            if (altTocFlatMatches(
              index.refTokensOf(i),
              q,
              dafCitation: dafCitation,
            ))
              i,
        ];
        expect(matchAltTocFlatIndex(index, q), expected, reason: '${q.length}');
      }
    },
    skip: dbPath == null || dbPath.isEmpty,
    timeout: const Timeout.factor(10),
  );
}

bool listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
