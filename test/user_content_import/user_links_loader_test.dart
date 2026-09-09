import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/user_content_import/services/user_links_loader.dart';

void main() {
  group('dedupeUserLinks', () {
    Link link(int i1, String p2, int i2, {String type = 'COMMENTARY'}) => Link(
      heRef: 'ref',
      index1: i1,
      path2: p2,
      index2: i2,
      connectionType: type,
    );

    test('קישור דו-כיווני (forward+inverse זהים) נשמר פעם אחת', () {
      final forward = Link(
        heRef: 'הכי גרסינן מגילה ב., א',
        index1: 3,
        path2: 'הכי גרסינן מגילה',
        index2: 5,
        connectionType: 'COMMENTARY',
        targetSource: BookSource.user,
        targetCategoryId: 7,
      );
      final inverse = Link(
        heRef: 'הכי גרסינן מגילה',
        index1: 3,
        path2: 'הכי גרסינן מגילה',
        index2: 5,
        connectionType: 'COMMENTARY',
        targetSource: BookSource.user,
        targetCategoryId: 7,
      );
      final result = dedupeUserLinks([forward, inverse]);
      expect(result, hasLength(1));
      // ה-forward ראשון — ה-heRef העשיר שלו נשמר
      expect(result.single.heRef, 'הכי גרסינן מגילה ב., א');
    });

    // ⚠️ הליבה של עוגני-המילה: שתי מילים בשורת הבסיס שמפנות לאותה שורת מפרש
    // הן שני סמנים. מפתח בלי anchorStart היה משאיר אחד מהם.
    test('עוגנים שונים באותו צמד-שורות נשמרים כשניים', () {
      Link anchored(int start) => Link(
        heRef: 'מפרש א, ב',
        index1: 3,
        path2: 'מפרש',
        index2: 5,
        connectionType: 'COMMENTARY',
        anchorStart: start,
      );

      final result = dedupeUserLinks([anchored(5), anchored(40)]);
      expect(result.map((l) => l.anchorStart), [5, 40]);
    });

    test('אותו עוגן בדיוק עדיין ממוזג לאחד', () {
      Link anchored() => Link(
        heRef: 'מפרש א, ב',
        index1: 3,
        path2: 'מפרש',
        index2: 5,
        connectionType: 'COMMENTARY',
        anchorStart: 5,
      );

      expect(dedupeUserLinks([anchored(), anchored()]), hasLength(1));
    });

    test('הצד ההפוך (בלי עוגן) נבלע ברשומה המעוגנת ואינו מוצג פעמיים', () {
      final forward = Link(
        heRef: 'מפרש א, ב',
        index1: 3,
        path2: 'מפרש',
        index2: 5,
        connectionType: 'COMMENTARY',
        anchorStart: 5,
      );
      final inverse = Link(
        heRef: 'מפרש',
        index1: 3,
        path2: 'מפרש',
        index2: 5,
        connectionType: 'COMMENTARY',
      );

      final result = dedupeUserLinks([forward, inverse]);
      expect(result, hasLength(1));
      expect(result.single.anchorStart, 5);
    });

    test('אותה כותרת אך ספר אישי/רשמי או קטגוריה שונה — לא ממוזגים', () {
      Link toBook(int i1, {required bool isUser, int? categoryId}) => Link(
        heRef: 'ref',
        index1: i1,
        path2: 'משותף',
        index2: 5,
        connectionType: 'COMMENTARY',
        targetSource: BookSource.fromUserFlag(isUser),
        targetCategoryId: categoryId,
      );
      final result = dedupeUserLinks([
        toBook(3, isUser: true, categoryId: 7),
        toBook(3, isUser: false, categoryId: 7),
        toBook(3, isUser: true, categoryId: 8),
      ]);
      expect(result, hasLength(3));
    });

    test('קישורים שונים (שורה/ספר/סוג) אינם ממוזגים', () {
      final result = dedupeUserLinks([
        link(3, 'פירוש', 5),
        link(4, 'פירוש', 5),
        link(3, 'פירוש אחר', 5),
        link(3, 'פירוש', 6),
        link(3, 'פירוש', 5, type: 'REFERENCE'),
      ]);
      expect(result, hasLength(5));
    });
  });
}
