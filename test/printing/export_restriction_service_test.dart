import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/printing/export_restriction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(ExportRestrictionService.resetForTesting);

  group('ExportRestrictionService - זיהוי ספר מוגבל', () {
    test('מזהה ספר שברשימה ולא ספר אחר', () {
      ExportRestrictionService.setRestrictedTitlesForTesting(const [
        'שמירת שבת כהלכתה - א',
      ]);

      expect(
        ExportRestrictionService.isRestricted('שמירת שבת כהלכתה - א'),
        isTrue,
      );
      expect(ExportRestrictionService.isRestricted('משנה ברורה'), isFalse);
      expect(ExportRestrictionService.isRestricted(null), isFalse);
    });

    test('מתעלם מרווחים מיותרים בשם', () {
      ExportRestrictionService.setRestrictedTitlesForTesting(const [
        'שמירת שבת כהלכתה - א',
      ]);

      expect(
        ExportRestrictionService.isRestricted('  שמירת שבת   כהלכתה - א '),
        isTrue,
      );
    });

    test('anyRestricted מזהה מפרש מוגבל בתוך רשימה', () {
      ExportRestrictionService.setRestrictedTitlesForTesting(const [
        'הערות על שמירת שבת כהלכתה - א',
      ]);

      expect(
        ExportRestrictionService.anyRestricted(const [
          'רש"י',
          'הערות על שמירת שבת כהלכתה - א',
        ]),
        isTrue,
      );
      expect(
        ExportRestrictionService.anyRestricted(const ['רש"י', 'תוספות']),
        isFalse,
      );
    });

    test('בלי טעינה — אין הגבלה', () {
      expect(
        ExportRestrictionService.isRestricted('שמירת שבת כהלכתה - א'),
        isFalse,
      );
    });
  });

  group('ExportRestrictionService - חסימת ייצוא במסמך הדפסה', () {
    setUp(() {
      ExportRestrictionService.setRestrictedTitlesForTesting(const [
        'שמירת שבת כהלכתה - א',
        'הערות על שמירת שבת כהלכתה - א',
      ]);
    });

    test('הספר עצמו מוגבל — חסום', () {
      expect(
        ExportRestrictionService.blocksEditableExport(
          documentTitle: 'שמירת שבת כהלכתה - א',
          commentariesIncluded: false,
          commentators: const [],
        ),
        isTrue,
      );
    });

    test('מפרש מוגבל נכלל בפלט — חסום', () {
      expect(
        ExportRestrictionService.blocksEditableExport(
          documentTitle: 'משנה ברורה',
          commentariesIncluded: true,
          commentators: const ['הערות על שמירת שבת כהלכתה - א'],
        ),
        isTrue,
      );
    });

    test('מפרש מוגבל שאינו נכלל בפלט — מותר', () {
      expect(
        ExportRestrictionService.blocksEditableExport(
          documentTitle: 'משנה ברורה',
          commentariesIncluded: false,
          commentators: const ['הערות על שמירת שבת כהלכתה - א'],
        ),
        isFalse,
      );
    });

    test('ספר ומפרשים שאינם מוגבלים — מותר', () {
      expect(
        ExportRestrictionService.blocksEditableExport(
          documentTitle: 'משנה ברורה',
          commentariesIncluded: true,
          commentators: const ['ביאור הלכה', 'שער הציון'],
        ),
        isFalse,
      );
    });
  });

  group('ExportRestrictionService - טעינה מהנכס', () {
    test('הרשימה המצורפת לאפליקציה כוללת את הספרים המוגבלים', () async {
      await ExportRestrictionService.ensureLoaded();

      expect(
        ExportRestrictionService.isRestricted('שמירת שבת כהלכתה - א'),
        isTrue,
      );
      expect(
        ExportRestrictionService.isRestricted('הערות על שמירת שבת כהלכתה - א'),
        isTrue,
      );
      expect(
        ExportRestrictionService.isRestricted('השלמה על עבודה זרה'),
        isTrue,
      );
      expect(ExportRestrictionService.isRestricted('משנה ברורה'), isFalse);
    });
  });
}
