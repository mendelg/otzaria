import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/l10n/settings_catalogs.g.dart';

void main() {
  test('אין מחרוזות ממשק עם הכתיב "ספריה" (issue #1189)', () {
    final singleYod = kSettingsCatalogs['en']!.keys
        .where((key) => key.contains('ספריה'))
        .toList();
    expect(singleYod, isEmpty, reason: 'מפתחות בכתיב חסר: $singleYod');
  });

  test(
    '"קטגוריות" מתואר בלשון נקבה: "מסוימות" ולא "מסוימים" (issue #1996)',
    () {
      final wrong = kSettingsCatalogs['en']!.keys
          .where((key) => key.contains('קטגוריות מסוימים'))
          .toList();
      expect(wrong, isEmpty, reason: 'מפתחות עם התאמה שגויה: $wrong');
    },
  );
}
