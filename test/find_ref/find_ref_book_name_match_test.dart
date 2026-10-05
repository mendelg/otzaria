import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/find_ref/book_name_match.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

import 'support/seeded_reference_library.dart';

/// צורת ההשוואה של שמות ספרים: וו/יי כפולות, ה"א הידיעה לפני ראשי-תיבות,
/// והעדפת הכתיב שבגרשיים בשוויון.
void main() {
  tearDown(resetSeededLibrary);

  group('bookNameMatchToken', () {
    test('וו/יי כפולות כיחידה', () {
      expect(bookNameMatchToken('מקוואות'), 'מקואות');
      expect(bookNameMatchToken('חיים'), 'חים');
      expect(bookNameMatchToken('שבת'), 'שבת');
    });

    test('ה"א הידיעה נשמטת רק לפני ראשי-תיבות שברשימה', () {
      expect(bookNameMatchToken('הרמבם'), 'רמבם');
      expect(bookNameMatchToken('השס'), 'שס');
      // רש"י וחז"ל אינם מקבלים ה"א, ומילה רגילה אינה ראשי-תיבות
      expect(bookNameMatchToken('הרשי'), 'הרשי');
      expect(bookNameMatchToken('החזל'), 'החזל');
      expect(bookNameMatchToken('הלכות'), 'הלכות');
    });

    test('quotedWordsOf: רק גרשיים בתוך מילה', () {
      expect(
        quotedWordsOf('רמב"ם הל\' שבת', normalizeForFindRefMatch),
        {'רמבם'},
      );
      expect(quotedWordsOf('שו״ע או״ח', normalizeForFindRefMatch), {
        'שוע',
        'אוח',
      });
      expect(quotedWordsOf('רמבם שבת', normalizeForFindRefMatch), isEmpty);
    });
  });

  group('BookTitleIndex', () {
    test('"מקואות" מזהה כינוי בכתיב "מקוואות" כהתאמה מלאה ולא מקורבת', () {
      seedLibrary(const [
        (
          id: 1,
          title: 'בן אריה על משנה תורה, הלכות מקוואות',
          acronyms: ['בן אריה מקוואות'],
        ),
      ]);
      final hits = ReferenceBooksCache.instance.search('בן אריה מקואות');
      expect(hits.single.matchRank, 3);
      // התוצאה נושאת את הכינוי בצורתו הרגילה, כמו שהיה בלי צורת ההשוואה
      expect(hits.single.matchedTerm, 'בן אריה מקוואות');
    });

    test('"הרמב״ם הלכות שבת" מזהה את הכינוי "רמב״ם הלכות שבת"', () {
      seedLibrary(const [
        (
          id: 1,
          title: 'משנה תורה, הלכות שבת',
          acronyms: ['רמב"ם הלכות שבת'],
        ),
      ]);
      final hits = ReferenceBooksCache.instance.search('הרמב״ם הלכות שבת');
      expect(hits.single.matchRank, 3);
    });

    test('כותרת עם ה"א נמצאת גם בלעדיה, ולהיפך', () {
      seedLibrary(const [
        (id: 1, title: 'השגות הראב"ד על בבא קמא', acronyms: []),
      ]);
      expect(
        ReferenceBooksCache.instance.search('השגות ראב"ד').single.matchRank,
        1,
      );
    });
  });

  group('findRefs — העדפת הכתיב שבגרשיים', () {
    test('בשוויון קודם ספר שכינויו כתוב בגרשיים כמו השאילתה', () async {
      // לשני הספרים כינוי זהה אחרי נרמול; בלי ההעדפה הראשון ברשימה קודם.
      seedLibrary(const [
        (id: 1, title: 'ספר ראשון', acronyms: ['רמבם']),
        (id: 2, title: 'ספר שני', acronyms: ['רמב"ם']),
      ]);
      final quoted = (await buildFindRefRepo().findRefs(
        'רמב"ם',
      )).map((r) => r.title).toList();
      expect(quoted.indexOf('ספר שני'), lessThan(quoted.indexOf('ספר ראשון')));

      final plain = (await buildFindRefRepo().findRefs(
        'רמבם',
      )).map((r) => r.title).toList();
      expect(plain.indexOf('ספר ראשון'), lessThan(plain.indexOf('ספר שני')));
    });
  });
}
