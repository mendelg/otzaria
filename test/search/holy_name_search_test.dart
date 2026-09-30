import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/search_engine_gateway.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/text_renderer_service.dart';

import '../support/recording_search_engine.dart';
import '../support/search_engine_test_init.dart';

/// שם הוי"ה בכתיב escapes, כדי שלא ייכתב בקוד המקור.
const _name = 'יהוה';
const _placeholder = 'יקוק';

/// פורום אוצריא, נושא 981: "יקוק" שהועתק מהתצוגה לא מצא את השם עצמו.
Future<void> main() async {
  final engineReady = await tryInitSearchEngine();

  group('withHolyNameAlternatives', () {
    test('מוסיף את השם כחלופה למילת "יקוק", עם אותיות השימוש שלפניה', () {
      expect(withHolyNameAlternatives('$_placeholder אלהינו', const {}), {
        0: [_name],
      });
      expect(withHolyNameAlternatives('יודו ל$_placeholder חסדו', const {}), {
        1: ['ל$_name'],
      });
    });

    test('משמר חלופות קיימות ואינו משכפל בקריאה חוזרת', () {
      final once = withHolyNameAlternatives('$_placeholder אחד', const {
        0: ['אדני'],
        1: ['יחיד'],
      });
      expect(once, {
        0: ['אדני', _name],
        1: ['יחיד'],
      });
      expect(withHolyNameAlternatives('$_placeholder אחד', once), once);
    });

    test('שאילתה בלי "יקוק" כמילה שלמה חוזרת כמות שהיא', () {
      const alternatives = {
        0: ['א'],
      };
      for (final query in [
        'שלום עולם',
        '$_placeholderים',
        'אבג$_placeholder',
      ]) {
        expect(
          identical(
            withHolyNameAlternatives(query, alternatives),
            alternatives,
          ),
          isTrue,
          reason: query,
        );
      }
    });
  }, skip: engineReady ? false : searchEngineSkipReason);

  group('SearchEngineGateway', () {
    const gateway = SearchEngineGateway();

    test('חיפוש רגיל עם "יקוק" עובר למתקדם עם השם כחלופה', () async {
      final engine = RecordingSearchEngine();
      await gateway.search(
        engine,
        const SearchEngineRequest(query: '$_placeholder אלהינו', facets: ['/']),
      );
      expect(engine.lastRequest!.searchMode, SearchMode.advanced);
      expect(engine.lastRequest!.alternativeWords, {
        0: [_name],
      });
    });

    test('חיפוש מתקדם שומר את המצב ומוסיף את החלופה', () async {
      final engine = RecordingSearchEngine();
      await gateway.search(
        engine,
        const SearchEngineRequest(
          query: 'ברוך $_placeholder',
          facets: ['/'],
          searchMode: SearchMode.advanced,
          distance: 3,
        ),
      );
      expect(engine.lastRequest!.searchMode, SearchMode.advanced);
      expect(engine.lastRequest!.distance, 3);
      expect(engine.lastRequest!.alternativeWords, {
        1: [_name],
      });
    });

    test('חיפוש בלי "יקוק" ומקורב אינם משתנים', () async {
      final engine = RecordingSearchEngine();
      const plain = SearchEngineRequest(query: 'שלום עולם', facets: ['/']);
      await gateway.search(engine, plain);
      expect(identical(engine.lastRequest, plain), isTrue);

      const fuzzy = SearchEngineRequest(
        query: '$_placeholder אלהינו',
        facets: ['/'],
        searchMode: SearchMode.fuzzy,
      );
      await gateway.search(engine, fuzzy);
      expect(identical(engine.lastRequest, fuzzy), isTrue);
    });
  }, skip: engineReady ? false : searchEngineSkipReason);

  test(
    'בספר פתוח "יקוק" שהוקלד מדגיש את השם, גם כשהתצוגה מחליפה אותו',
    () {
      const line = 'יודו ל$_name חסדו';
      final out = TextRendererService.processText(
        line,
        const RenderSettings(
          searchText: 'יודו ל$_placeholder חסדו',
          replaceHolyNames: true,
        ),
      );
      expect(out, isNot(contains(_name)));
      expect(out, contains('<span style="color: red">יודו</span>'));
      expect(out, contains('<span style="color: red">חסדו</span>'));
    },
    skip: engineReady ? false : searchEngineSkipReason,
  );
}
