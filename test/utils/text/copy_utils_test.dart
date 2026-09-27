import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/file/toc_parser.dart';
import 'package:otzaria/utils/text/copy_utils.dart';

void main() {
  group('CopyUtils.referencePath — גזירת נתיב מ-reference של תוצאת חיפוש', () {
    test('reference שאינו פותח בשם הספר מוחזר כמות שהוא', () {
      expect(
        CopyUtils.referencePath(bookName: 'ספר א', reference: 'סימן א'),
        'סימן א',
      );
    });

    test('reference שפותח בשם הספר ופסיק — הנתיב בלבד', () {
      expect(
        CopyUtils.referencePath(
          bookName: 'עבודה זרה',
          reference: 'עבודה זרה, דף עג.',
        ),
        'דף עג.',
      );
    });

    test('reference שפותח בשם הספר בלי פסיק — השארית בלבד', () {
      expect(
        CopyUtils.referencePath(
          bookName: 'בראשית',
          reference: 'בראשית פרק ד',
        ),
        'פרק ד',
      );
    });

    test('reference שמתחיל במילה עם קידומת שם הספר מוחזר כמות שהוא', () {
      expect(
        CopyUtils.referencePath(bookName: 'ספר', reference: 'ספרים, שער א'),
        'ספרים, שער א',
      );
    });

    test('reference שזהה לשם הספר — נתיב ריק (בלי הכפלה)', () {
      expect(
        CopyUtils.referencePath(bookName: 'ספר א', reference: 'ספר א'),
        '',
      );
    });

    test('שם ספר ריק — ה-reference מוחזר כמות שהוא', () {
      expect(
        CopyUtils.referencePath(bookName: '', reference: 'סימן א'),
        'סימן א',
      );
    });
  });

  group('CopyUtils.formatTextWithHeaders — שילוב עם הנתיב שנגזר', () {
    test('book_and_path עם נתיב ריק נופל לשם הספר בלבד', () {
      expect(
        CopyUtils.formatTextWithHeaders(
          originalText: 'טקסט',
          copyWithHeaders: 'book_and_path',
          copyHeaderFormat: 'same_line_after_brackets',
          bookName: 'ספר א',
          currentPath: '',
        ),
        'טקסט (ספר א)',
      );
    });

    test('book_and_path עם נתיב מלא מרכיב "ספר, נתיב"', () {
      expect(
        CopyUtils.formatTextWithHeaders(
          originalText: 'טקסט',
          copyWithHeaders: 'book_and_path',
          copyHeaderFormat: 'separate_line_before',
          bookName: 'עבודה זרה',
          currentPath: 'דף עג.',
        ),
        'עבודה זרה, דף עג.\nטקסט',
      );
    });
  });

  group('CopyUtils.extractCurrentPath — נתיב מעץ הכותרות', () {
    TextBook bookWithToc() {
      final root = TocEntry(text: 'רש"י על בראשית', index: 0);
      final chapterA = TocEntry(
        text: 'פרק א',
        index: 1,
        level: 2,
        parent: root,
      );
      final verseD = TocEntry(
        text: 'פסוק ד',
        index: 2,
        level: 3,
        parent: chapterA,
      );
      final chapterB = TocEntry(
        text: 'פרק ב',
        index: 5,
        level: 2,
        parent: root,
      );
      chapterA.children.add(verseD);
      root.children.addAll([chapterA, chapterB]);
      return _TocBook([root]);
    }

    test('כותרות צאצאים של השורש נכנסות לנתיב', () async {
      expect(
        await CopyUtils.extractCurrentPath(bookWithToc(), 3),
        'פרק א, פסוק ד',
      );
    });

    test('כותרת עמוקה של פרק קודם לא נכנסת לפרק הבא', () async {
      expect(await CopyUtils.extractCurrentPath(bookWithToc(), 6), 'פרק ב');
    });

    test('דילוג ברמות בעץ מקובץ לא משבש את סדר הכותרות', () async {
      // h4 אחרי h2 נתלית בעץ תחת ה-h3 של הפרק הקודם.
      final book = _TocBook(
        TocParser.parseEntriesFromContent(
          '<h1>ספר</h1>\n<h2>פרק א</h2>\n<h3>הלכה א</h3>\nטקסט\n'
          'טקסט\n<h2>פרק ב</h2>\n<h4>סעיף א</h4>\nטקסט',
        ),
      );
      expect(await CopyUtils.extractCurrentPath(book, 5), 'פרק ב');
      expect(await CopyUtils.extractCurrentPath(book, 7), 'פרק ב, סעיף א');
    });
  });
}

class _TocBook extends TextBook {
  _TocBook(this._toc) : super(title: 'ספר');

  final List<TocEntry> _toc;

  @override
  Future<List<TocEntry>> get tableOfContents async => _toc;
}
