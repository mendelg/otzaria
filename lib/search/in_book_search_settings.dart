import 'package:flutter/foundation.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/search_query_builder.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/search/utils/in_book_search_routing.dart';
import 'package:otzaria/search/view/search_dialog.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

/// The settings of an in-book search besides the query, shared by the text
/// and PDF search panes: the mode, the distance, the match policy and the
/// per-word options.
@immutable
class InBookSearchSettings {
  const InBookSearchSettings({
    this.searchOptions = const {},
    this.alternativeWords = const {},
    this.spacingValues = const {},
    this.searchMode = SearchMode.exact,
    this.distance = 0,
    this.matchPolicy = SearchMatchPolicy.standard,
  });

  /// The settings submitted in the advanced search dialog, with the per-word
  /// options normalized for the chosen mode.
  factory InBookSearchSettings.fromDialogResult(SearchDialogResult result) {
    final normalized = SearchQueryBuilder.normalizeParametersForMode(
      result.searchMode,
      customSpacing: result.spacingValues,
      alternativeWords: result.alternativeWords,
      searchOptions: result.searchOptions,
    );
    return InBookSearchSettings(
      searchOptions: normalized.searchOptions,
      alternativeWords: normalized.alternativeWords,
      spacingValues: normalized.customSpacing,
      searchMode: result.searchMode,
      distance: result.distance,
      matchPolicy: result.matchPolicy,
    );
  }

  final Map<String, Map<String, bool>> searchOptions;
  final Map<int, List<String>> alternativeWords;
  final Map<String, String> spacingValues;
  final SearchMode searchMode;
  final int distance;
  final SearchMatchPolicy matchPolicy;

  /// Whether these settings need the search engine rather than the local
  /// literal scan.
  bool get requiresEngine => !InBookSearchRouting.canRunAsSimpleSearch(
    searchMode: searchMode,
    distance: distance,
    searchOptions: searchOptions,
    alternativeWords: alternativeWords,
    spacingValues: spacingValues,
    matchPolicy: matchPolicy,
  );

  /// Whether the search runs as the local literal scan.
  bool get isSimpleSearch => !requiresEngine && searchMode == SearchMode.exact;

  /// The per-word options that apply to [searchMode].
  SearchModeScopedParameters get activeParameters =>
      SearchQueryBuilder.normalizeParametersForMode(
        searchMode,
        customSpacing: spacingValues,
        alternativeWords: alternativeWords,
        searchOptions: searchOptions,
      );
}

/// The query an in-book search runs for [raw]: trimmed and without nikud, or
/// null when there is nothing to search for.
String? searchableInBookQuery(String raw) {
  var query = raw.trim();
  if (utils.hasNikud(query)) {
    query = utils.removeVolwels(query);
  }
  return query.isEmpty ? null : query;
}

/// Searches the book whose facet is [bookPath] for [query] through the
/// search engine, with [settings], in the book's order.
Future<List<SearchResult>> searchBookWithEngine(
  SearchRepository repository, {
  required String query,
  required String bookPath,
  required int limit,
  required InBookSearchSettings settings,
}) {
  final parameters = settings.activeParameters;
  final policy = settings.matchPolicy;
  return repository.searchTexts(
    query,
    [bookPath],
    limit,
    searchOptions: parameters.searchOptions,
    alternativeWords: parameters.alternativeWords,
    customSpacing: parameters.customSpacing,
    fuzzy: settings.searchMode == SearchMode.fuzzy,
    distance: settings.distance,
    searchMode: settings.searchMode,
    scope: policy.proximityScope,
    wordMatchMode: policy.wordMatchMode,
    wordMatchCount: policy.wordMatchCount,
    order: ResultsOrder.catalogue,
  );
}
