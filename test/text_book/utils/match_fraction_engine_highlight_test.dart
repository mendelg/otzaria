import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/utils/section_search_utils.dart';

import '../../support/search_engine_test_init.dart';

/// הגלילה אל ההופעה מחושבת באותה תבנית שבה הספר מדגיש, גם בחיפוש עם מרווח.
Future<void> main() async {
  final engineReady = await tryInitSearchEngine();

  // רשב"א בערך באמצע השורה, וגיטין שלוש מילים אחריו.
  final line = [
    for (var i = 0; i < 40; i++) 'מילה',
    'הרשב"א',
    'כתב',
    'בזה',
    'בפרק',
    'גיטין',
    for (var i = 0; i < 40; i++) 'סוף',
  ].join(' ');
  final expected = line.indexOf('רשב"א') / line.length;

  group('גלילה אל ההופעה בחיפוש עם מרווח (issue #1642)', () {
    test(
      'מרחק בין מילים: השבר נגזר מתבנית ההדגשה ולא מהשאילתה הרצופה',
      () {
        final fraction = matchFractionInLine(
          line,
          'רשב"א גיטין',
          searchDistance: 30,
          searchOptions: const {
            'רשב"א_0': {'קידומות': true},
          },
        );
        expect(fraction, closeTo(expected, 0.001));
      },
      skip: engineReady ? false : searchEngineSkipReason,
    );

    test(
      'שאילתה רצופה בלי אפשרויות: השבר לפי תחילת הביטוי',
      () {
        final fraction = matchFractionInLine(line, 'בפרק גיטין');
        expect(fraction, closeTo(line.indexOf('בפרק') / line.length, 0.001));
      },
      skip: engineReady ? false : searchEngineSkipReason,
    );
  });
}
