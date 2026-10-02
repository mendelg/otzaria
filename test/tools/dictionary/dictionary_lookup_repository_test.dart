import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/dictionary/dictionary_context_menu_entries.dart';
import 'package:otzaria/tools/dictionary/repository/dictionary_lookup_repository.dart';

void main() {
  group('DictionaryLookupRepository', () {
    late DictionaryLookupRepository repository;

    setUp(() {
      repository = DictionaryLookupRepository(
        loadAcronyms: () async => <String, List<String>>{
          'רש"י': <String>['רבי שלמה יצחקי', 'רבן של ישראל'],
          "וכו'": <String>['וכולי, וכן הלאה'],
        },
        loadAramaicEntries: () async => const <AramaicDictionaryEntry>[
          AramaicDictionaryEntry(aramaic: 'אבא', hebrew: 'יער'),
          AramaicDictionaryEntry(aramaic: 'בר אבא', hebrew: 'בן היער'),
          AramaicDictionaryEntry(aramaic: 'אבוה', hebrew: 'אביו'),
        ],
        loadLaazEntries: () async => const <LaazDictionaryEntry>[],
      );
    });

    test('מוצא ראשי תיבות גם עם גרשיים עבריים', () async {
      await repository.ensureLoaded();

      final entry = repository.findAcronym('רש״י');

      expect(entry, isNotNull);
      expect(entry!.meanings, contains('רבי שלמה יצחקי'));
      expect(entry.meanings, contains('רבן של ישראל'));
    });

    test('מוצא קיצורים עם גרש בודד', () async {
      await repository.ensureLoaded();

      final entry = repository.findAcronym("וכו'");

      expect(entry, isNotNull);
      expect(entry!.meanings, contains('וכולי, וכן הלאה'));
    });

    test('מחזיר הרחבות לראשי תיבות חלקיים עם גרש בודד', () async {
      repository = DictionaryLookupRepository(
        loadAcronyms: () async => <String, List<String>>{
          'ועי"ל': <String>['ועיין לעיל'],
          'ועי"ש': <String>['ועיין שם'],
        },
        loadAramaicEntries: () async => const <AramaicDictionaryEntry>[
          AramaicDictionaryEntry(aramaic: 'אבא', hebrew: 'יער'),
        ],
      );
      await repository.ensureAcronymsLoaded();

      final matches = repository.findAcronymMatches("ועי'");

      expect(matches.map((entry) => entry.acronym), <String>[
        'ועי"ל',
        'ועי"ש',
      ]);
    });

    test('שאילתת חיפוש מנורמלת מזהה גרש מול גרשיים', () async {
      await repository.ensureAcronymsLoaded();

      final matches = repository.acronymMatchesQuery(
        acronym: 'וכ"ו',
        query: "וכו'",
      );

      expect(matches, isTrue);
    });

    test('מחזיר צירופים ארמיים רק אם המילה קיימת כמונח במילון', () async {
      await repository.ensureLoaded();

      final matches = repository.findAramaicMatches('אבא');

      expect(matches.map((entry) => entry.aramaic), <String>[
        'אבא',
        'בר אבא',
      ]);
    });

    test('לא מחזיר צירופים אם המילה לא קיימת במילון כמונח עצמאי', () async {
      await repository.ensureLoaded();

      final matches = repository.findAramaicMatches('אביו');

      expect(matches, isEmpty);
    });
  });

  group('getAcronymSearchCatalog (issue: חיפוש ראשי תיבות איטי)', () {
    // מילון סינתטי בסדר גודל של המילון האמיתי (כ-13,000 ערכים), כדי שהבדל
    // הביצועים בין נירמול-פעם-אחת לנירמול-לכל-רשומה יהיה מדיד ולא רועש.
    // אותיות עבריות בלבד, בלי ספרות: _trimDecorations גוזם ספרות וסימנים
    // זרים מקצה המחרוזת, וכל סיומת מספרית הייתה מתכווצת לאותו מפתח מנורמל
    // יחיד — בדיוק המלכודת שתפסה את הבדיקה הראשונה בטיוטה הזאת.
    const hebrewLetters = 'אבגדהוזחטיכלמנסעפצקרשת'; // 22 אותיות, בלי סופיות
    const letterBase = hebrewLetters.length;
    String uniqueAcronymBody(int i) {
      final c1 = hebrewLetters[(i ~/ (letterBase * letterBase)) % letterBase];
      final c2 = hebrewLetters[(i ~/ letterBase) % letterBase];
      final c3 = hebrewLetters[i % letterBase];
      return '$c1$c2$c3';
    }

    /// בונה את ראשי-התיבות המלאים (עם הגרשיים) לאינדקס נתון — אותה נוסחה
    /// בדיוק כמו [buildLargeAcronymMap], כדי שבדיקות יוכלו לבנות שאילתות
    /// אמיתיות (ולא מנחשות) מתוך אותה טבלה.
    String acronymFor(int i) {
      final body = uniqueAcronymBody(i);
      // גרשיים כפולים/בודדים מערבבים צורות שדורשות נירמול אמיתי, לא רק
      // השוואת מחרוזות — אחרת הבדיקה הייתה יכולה לעבור גם בלי התיקון.
      final mark = i.isEven ? '"' : "'";
      return '${body.substring(0, body.length - 1)}$mark${body.substring(body.length - 1)}';
    }

    Map<String, List<String>> buildLargeAcronymMap(int count) {
      final map = <String, List<String>>{};
      for (var i = 0; i < count; i++) {
        map[acronymFor(i)] = <String>['פירוש מספר $i', 'עוד פירוש ל-$i'];
      }
      return map;
    }

    /// מסלול החיפוש הישן: מנרמל כל מפתח בקטלוג מחדש בכל קריאה ל-
    /// acronymMatchesQuery — כפי שהמסך עשה לפני התיקון.
    List<String> searchLegacy(
      DictionaryLookupRepository repo,
      Map<String, List<String>> dictionaryData,
      String query,
    ) {
      return dictionaryData.entries
          .where(
            (entry) =>
                entry.key.contains(query) ||
                repo.acronymMatchesQuery(acronym: entry.key, query: query) ||
                entry.value.any((meaning) => meaning.contains(query)),
          )
          .map((entry) => entry.key)
          .toList();
    }

    /// מסלול החיפוש החדש: המפתח המנורמל כבר מחושב בקטלוג, והשאילתה מנורמלת
    /// פעם אחת בלבד.
    List<String> searchCatalog(
      DictionaryLookupRepository repo,
      List<AcronymCatalogEntry> catalog,
      String query,
    ) {
      final normalizedQuery = repo.normalizeAcronymQuery(query);
      return catalog
          .where(
            (entry) =>
                entry.displayAcronym.contains(query) ||
                (normalizedQuery.isNotEmpty &&
                    entry.normalizedKey.contains(normalizedQuery)) ||
                entry.meanings.any((meaning) => meaning.contains(query)),
          )
          .map((entry) => entry.displayAcronym)
          .toList();
    }

    test('המפתח המנורמל בקטלוג זהה לנירמול שהמסלול הישן היה מחשב', () async {
      final dictionaryData = buildLargeAcronymMap(50);
      final repo = DictionaryLookupRepository(
        loadAcronyms: () async => dictionaryData,
        loadAramaicEntries: () async => const [],
        loadLaazEntries: () async => const [],
      );
      await repo.ensureAcronymsLoaded();

      final catalog = repo.getAcronymSearchCatalog();
      expect(catalog, isNotEmpty);
      for (final entry in catalog) {
        expect(
          entry.normalizedKey,
          repo.normalizeAcronymQuery(entry.displayAcronym),
        );
      }
    });

    test(
      'מחזיר בדיוק את אותן תוצאות כמו המסלול הישן, על אותו מילון',
      () async {
        final dictionaryData = buildLargeAcronymMap(500);
        final repo = DictionaryLookupRepository(
          loadAcronyms: () async => dictionaryData,
          loadAramaicEntries: () async => const [],
          loadLaazEntries: () async => const [],
        );
        await repo.ensureAcronymsLoaded();
        final catalog = repo.getAcronymSearchCatalog();

        final queries = <String>[
          hebrewLetters[0], // אות בודדת — תתאים לחלק ניכר מהקטלוג
          acronymFor(7), // התאמה מדויקת, כולל הגרש/גרשיים
          acronymFor(321).substring(0, 2), // התאמה חלקית מהתחלה
        ];
        for (final query in queries) {
          final legacy = searchLegacy(repo, dictionaryData, query)..sort();
          final updated = searchCatalog(repo, catalog, query)..sort();
          expect(
            updated,
            legacy,
            reason: 'השאילתה "$query" הניבה תוצאות שונות מהמסלול הישן',
          );
        }
      },
    );

    test(
      'מסלול הקטלוג מהיר משמעותית מהמסלול הישן על מילון בגודל אמיתי',
      () async {
        // 22^3 = 10,648 מפתחות בני 3 אותיות בלבד אפשריים עם ה-builder הנוכחי;
        // 9,000 נשאר קרוב בגודלו למילון האמיתי (12,832 אחרי מיזוג התנגשויות)
        // בלי להתנגש בתקרה.
        final dictionaryData = buildLargeAcronymMap(9000);
        final repo = DictionaryLookupRepository(
          loadAcronyms: () async => dictionaryData,
          loadAramaicEntries: () async => const [],
          loadLaazEntries: () async => const [],
        );
        await repo.ensureAcronymsLoaded();
        final catalog = repo.getAcronymSearchCatalog();

        final queries = <String>[
          hebrewLetters[0],
          acronymFor(7),
          acronymFor(321).substring(0, 2),
          hebrewLetters[10],
        ];

        final legacyStopwatch = Stopwatch()..start();
        for (final query in queries) {
          searchLegacy(repo, dictionaryData, query);
        }
        legacyStopwatch.stop();

        final catalogStopwatch = Stopwatch()..start();
        for (final query in queries) {
          searchCatalog(repo, catalog, query);
        }
        catalogStopwatch.stop();

        // סף פי 3 משאיר מרווח לתנודות זמן במכונות CI איטיות.
        expect(
          legacyStopwatch.elapsedMicroseconds,
          greaterThan(catalogStopwatch.elapsedMicroseconds * 3),
          reason:
              'מסלול הקטלוג (${catalogStopwatch.elapsedMicroseconds}µs) '
              'אמור להיות מהיר בהרבה מהמסלול הישן '
              '(${legacyStopwatch.elapsedMicroseconds}µs)',
        );
      },
    );
  });

  group('AramaicDictionaryEntryPresentation', () {
    test('מפרק פירושים מרובים לצורות תצוגה נפרדות', () {
      final presentation = AramaicDictionaryEntryPresentation.parse(
        '{אַהֲנֵי} הועיל *** {אַהָנֵי} (=א הני) על אלה',
      );

      expect(presentation.meanings, hasLength(2));
      expect(presentation.meanings.first.expression, 'אַהֲנֵי');
      expect(presentation.meanings.first.mainText, 'הועיל');
      expect(presentation.meanings.first.expansion, isNull);
      expect(presentation.meanings.last.expression, 'אַהָנֵי');
      expect(presentation.meanings.last.mainText, 'על אלה');
      expect(presentation.meanings.last.expansion, 'א הני');
    });

    test('מפרק גם הסבר שמופיע בתחילת הפירוש בלי ציטוט', () {
      final presentation = AramaicDictionaryEntryPresentation.parse(
        '(=אם תימצי לומר) אם תשיב לשאלה הקודמת באופן זה',
      );

      expect(presentation.meanings, hasLength(1));
      expect(presentation.meanings.single.expression, isNull);
      expect(
        presentation.meanings.single.mainText,
        'אם תשיב לשאלה הקודמת באופן זה',
      );
      expect(presentation.meanings.single.expansion, 'אם תימצי לומר');
    });
  });

  group('buildDictionaryContextMenuEntries', () {
    late DictionaryLookupRepository repository;

    setUp(() {
      repository = DictionaryLookupRepository(
        loadAcronyms: () async => <String, List<String>>{
          'רש"י': <String>['רבי שלמה יצחקי'],
        },
        loadAramaicEntries: () async => const <AramaicDictionaryEntry>[
          AramaicDictionaryEntry(
            aramaic: 'אבא',
            hebrew: '{אַבָּא} אב *** {אֲבָא} רוצה',
          ),
        ],
        loadLaazEntries: () async => const <LaazDictionaryEntry>[],
      );
    });

    testWidgets('בונה תפריט משנה לראשי תיבות', (tester) async {
      await repository.ensureLoaded();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final entries = buildDictionaryContextMenuEntries(
        context: context,
        selectedText: 'רש״י',
        repository: repository,
      );

      expect(entries, hasLength(1));
    });

    testWidgets('בונה תפריט משנה למילה ארמית רגילה', (tester) async {
      await repository.ensureLoaded();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final entries = buildDictionaryContextMenuEntries(
        context: context,
        selectedText: 'אבא',
        repository: repository,
      );

      expect(entries, hasLength(1));
    });

    testWidgets('נופל חזרה לחיפוש ארמי כשאין התאמת ראשי תיבות', (tester) async {
      await repository.ensureLoaded();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final entries = buildDictionaryContextMenuEntries(
        context: context,
        selectedText: '"אבא"',
        repository: repository,
      );

      expect(entries, hasLength(1));
    });

    testWidgets('מציג חיפוש ארמי גם כשמילון ראשי התיבות לא נטען', (
      tester,
    ) async {
      await repository.ensureAramaicLoaded();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final entries = buildDictionaryContextMenuEntries(
        context: context,
        selectedText: 'אבא',
        repository: repository,
      );

      expect(entries, hasLength(1));
    });

    testWidgets('מציג ראשי תיבות גם כשמילון ארמי לא נטען', (tester) async {
      repository = DictionaryLookupRepository(
        loadAcronyms: () async => <String, List<String>>{
          'וכ"ו': <String>['וכו'],
        },
        loadAramaicEntries: () async => const <AramaicDictionaryEntry>[
          AramaicDictionaryEntry(aramaic: 'אבא', hebrew: 'יער'),
        ],
        loadLaazEntries: () async => const <LaazDictionaryEntry>[],
      );
      await repository.ensureAcronymsLoaded();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final entries = buildDictionaryContextMenuEntries(
        context: context,
        selectedText: "וכו'",
        repository: repository,
      );

      expect(entries, hasLength(1));
    });
  });
}
