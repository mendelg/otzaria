import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/in_book_search_settings.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/view/search_dialog.dart';

void main() {
  group('InBookSearchSettings', () {
    test('the default settings run as a simple search', () {
      const settings = InBookSearchSettings();
      expect(settings.requiresEngine, isFalse);
      expect(settings.isSimpleSearch, isTrue);
    });

    test('a distance or a per-word option needs the engine', () {
      expect(
        const InBookSearchSettings(distance: 2).isSimpleSearch,
        isFalse,
      );
      expect(
        const InBookSearchSettings(
          searchOptions: {
            'שלום_0': {'קידומות': true},
          },
        ).requiresEngine,
        isTrue,
      );
      expect(
        const InBookSearchSettings(
          alternativeWords: {
            0: ['שלם'],
          },
        ).requiresEngine,
        isTrue,
      );
    });

    test('advanced and fuzzy modes do not run as a simple search', () {
      expect(
        const InBookSearchSettings(
          searchMode: SearchMode.advanced,
        ).isSimpleSearch,
        isFalse,
      );
      expect(
        const InBookSearchSettings(searchMode: SearchMode.fuzzy).requiresEngine,
        isTrue,
      );
    });

    test('takes the dialog result with its mode, distance and policy', () {
      final settings = InBookSearchSettings.fromDialogResult(
        const SearchDialogResult(
          query: 'שלום',
          searchOptions: {
            'שלום_0': {'קידומות': true},
          },
          alternativeWords: {
            0: ['שלם'],
          },
          spacingValues: {},
          searchMode: SearchMode.advanced,
          distance: 3,
        ),
      );

      expect(settings.searchMode, SearchMode.advanced);
      expect(settings.distance, 3);
      expect(settings.matchPolicy, SearchMatchPolicy.standard);
      expect(settings.searchOptions['שלום_0'], {'קידומות': true});
      expect(settings.alternativeWords[0], ['שלם']);
    });
  });

  group('searchableInBookQuery', () {
    test('trims the query and drops nikud', () {
      expect(searchableInBookQuery('  שָׁלוֹם '), 'שלום');
    });

    test('a blank query has nothing to search for', () {
      expect(searchableInBookQuery(''), isNull);
      expect(searchableInBookQuery('   '), isNull);
    });
  });
}
