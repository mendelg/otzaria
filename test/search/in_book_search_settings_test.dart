import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/in_book_search_settings.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/search/view/search_dialog.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

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

  group('searchBookWithEngine', () {
    test('searches the book with the settings, in book order', () async {
      final repository = _RecordingSearchRepository();
      await searchBookWithEngine(
        repository,
        query: 'שלום',
        bookPath: '/תנך/בראשית',
        limit: 500,
        settings: const InBookSearchSettings(
          searchMode: SearchMode.fuzzy,
          distance: 2,
          alternativeWords: {
            0: ['שלם'],
          },
        ),
      );

      final call = repository.calls.single;
      expect(call.query, 'שלום');
      expect(call.facets, ['/תנך/בראשית']);
      expect(call.limit, 500);
      expect(call.fuzzy, isTrue);
      expect(call.distance, 2);
      expect(call.searchMode, SearchMode.fuzzy);
      expect(call.order, ResultsOrder.catalogue);
    });
  });
}

class _RecordingSearchRepository extends SearchRepository {
  final calls =
      <
        ({
          String query,
          List<String> facets,
          int limit,
          bool fuzzy,
          int distance,
          SearchMode searchMode,
          ResultsOrder order,
        })
      >[];

  @override
  Future<List<SearchResult>> searchTexts(
    String query,
    List<String> facets,
    int limit, {
    int offset = 0,
    ResultsOrder order = ResultsOrder.relevance,
    bool fuzzy = false,
    int distance = 0,
    String negativeQuery = '',
    int? negativeDistance,
    SearchScope scope = SearchScope.wordDistance,
    SearchScope? negativeScope,
    SearchMode searchMode = SearchMode.exact,
    Map<String, String>? customSpacing,
    Map<String, String>? negativeCustomSpacing,
    Map<int, List<String>>? alternativeWords,
    Map<int, List<String>>? negativeAlternativeWords,
    Map<String, Map<String, bool>>? searchOptions,
    Map<String, Map<String, bool>>? negativeSearchOptions,
    bool matchNikud = false,
    bool matchTaamim = false,
    ResultGrouping? grouping,
    WordMatchMode wordMatchMode = WordMatchMode.all,
    int? wordMatchCount,
  }) async {
    calls.add((
      query: query,
      facets: facets,
      limit: limit,
      fuzzy: fuzzy,
      distance: distance,
      searchMode: searchMode,
      order: order,
    ));
    return const [];
  }
}
