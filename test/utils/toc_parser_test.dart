import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/file/toc_parser.dart';
import 'package:otzaria/utils/text/ref_helper.dart';

void main() {
  group('TocParser.parseEntriesFromContent', () {
    test('parses HTML headings with leading whitespace', () {
      final content = '''
        <h1>כותרת ראשית</h1>
        טקסט רגיל
          <h2>כותרת משנה</h2>
        עוד טקסט
      ''';

      final toc = TocParser.parseEntriesFromContent(content);

      expect(toc.length, 1);
      expect(toc.first.text, 'כותרת ראשית');
      expect(toc.first.level, 1);
      expect(toc.first.children.length, 1);
      expect(toc.first.children.first.text, 'כותרת משנה');
      expect(toc.first.children.first.level, 2);
    });

    test('כותרת עם $kTocExcludeAttr מדולגת (תוכן עניינים מוטמע קובע)', () {
      final content =
          '<h1>ראשית</h1>\n'
          '<h2 $kTocExcludeAttr>כותרת עיצובית</h2>\n'
          '<h2>כותרת אמיתית</h2>';

      final toc = TocParser.parseEntriesFromContent(content);

      expect(toc.length, 1);
      expect(toc.first.children.map((e) => e.text), ['כותרת אמיתית']);
    });

    test('parses Markdown headings (#..######)', () {
      final content = '''
# פרק א
טקסט
## סעיף א
עוד טקסט
### תת סעיף
      ''';

      final toc = TocParser.parseEntriesFromContent(content);

      expect(toc.length, 1);
      expect(toc.first.text, 'פרק א');
      expect(toc.first.level, 1);
      expect(toc.first.children.length, 1);
      expect(toc.first.children.first.text, 'סעיף א');
      expect(toc.first.children.first.level, 2);
      expect(toc.first.children.first.children.length, 1);
      expect(toc.first.children.first.children.first.text, 'תת סעיף');
      expect(toc.first.children.first.children.first.level, 3);
    });

    test('כותרת אחרי דילוג רמה נתלית בכותרת הקודמת הקרובה ברמה נמוכה יותר', () {
      // המבנה של "סוד קיומנו או המחנך": h3 לפני הפרק הראשון, ואז h2 ו-h4.
      const content =
          '<h1>ספר</h1>\n'
          '<h3>הקדמה</h3>\n'
          '<h2>פרק א</h2>\n'
          '<h4>ברכה</h4>\n'
          '<h2>פרק ב</h2>\n'
          '<h4>ניסן</h4>\n'
          'טקסט';

      final toc = TocParser.parseEntriesFromContent(content);
      final flat = flattenToc(toc);

      expect(flat.map((e) => e.index), [0, 1, 2, 3, 4, 5]);
      expect(flat[1].parent?.text, 'ספר');
      expect(flat[3].parent?.text, 'פרק א');
      expect(flat[5].parent?.text, 'פרק ב');
      expect(refFromTocList(6, toc), 'ספר, פרק ב, ניסן');
    });

    test('does not treat hash-without-space as heading', () {
      final content = '###בלי רווח\nטקסט';
      final toc = TocParser.parseEntriesFromContent(content);
      expect(toc, isEmpty);
    });
  });
}
