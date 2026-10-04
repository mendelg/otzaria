import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:otzaria/data/data_providers/book_database_resolver.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/search/utils/facet_helper.dart';

import 'semantic_availability.dart';

/// האם להציג את המצב בבורר; גם תצוגת הפיתוח מוגבלת למחשבים נתמכים.
bool isSemanticModeVisible(
  SemanticAvailability availability, {
  bool debug = kDebugMode,
}) =>
    availability.hiddenReason != SemanticHiddenReason.unsupportedPlatform &&
    (debug || availability.phase != SemanticAvailabilityPhase.hidden);

/// תצוגה מקדימה בפיתוח: יש הסכמה, אבל חסרים מנוע או נתונים.
bool isSemanticDebugPreview(
  SemanticAvailability availability, {
  bool debug = kDebugMode,
}) =>
    debug && availability.consentGranted && availability.isMissingEngineOrData;

/// האם אפשר לחפש: מנוע מוכן עם הסכמה, או תצוגה מקדימה בפיתוח.
bool canRunSemanticSearch(
  SemanticAvailability availability, {
  bool debug = kDebugMode,
}) =>
    isSemanticModeVisible(availability, debug: debug) &&
    (availability.isUsable ||
        isSemanticDebugPreview(availability, debug: debug));

final RegExp _bookKeySegment = RegExp(r'^(id|uid|ext|db):|\|');

/// בחירה שלא ניתן לבצע בשלמותה חייבת תיקון לפני החיפוש, בלי הרחבת ההיקף.
bool semanticScopeIsSupported(
  Iterable<String> selection, {
  bool Function(String facet)? isOfficialCategory,
}) {
  final selected = selection.toSet();
  final categories = FacetHelper.categoryFacetsOf(selected).toSet();
  return categories.length == selected.length &&
      categories.every(
        (facet) =>
            _isLibraryCategory(facet) &&
            (facet == '/' || (isOfficialCategory?.call(facet) ?? true)),
      );
}

/// רק קטגוריות של הספרייה: בלי ממדים, בלי ספרים בודדים ובלי ספרים אישיים.
/// [isOfficialCategory] מסנן גם קטגוריות שמקורן במסדים מצורפים שמוזגו לעץ.
List<String> semanticScopeFacets(
  Iterable<String> selection, {
  bool Function(String facet)? isOfficialCategory,
}) {
  final facets = [
    for (final facet in FacetHelper.categoryFacetsOf(selection))
      if (_isLibraryCategory(facet) &&
          (facet == '/' || (isOfficialCategory?.call(facet) ?? true)))
        facet,
  ];
  if (facets.isEmpty || facets.contains('/')) return const ['/'];
  return facets..sort();
}

bool _isLibraryCategory(String facet) {
  if (facet == '/') return true;
  if (BookDatabaseResolver.likelySource(categoryPath: facet) !=
      BookSource.official) {
    return false;
  }
  return !facet.split('/').any(_bookKeySegment.hasMatch);
}

/// האם בקטגוריה של [facet] יש ספר מהספרייה הרשמית; `null` כשהספרייה לא נטענה.
bool Function(String facet)? officialCategoryFilter(Library? library) {
  if (library == null) return null;
  return (facet) {
    Category? category = library;
    for (final title in facet.split('/').where((part) => part.isNotEmpty)) {
      category = category?.subCategories
          .where((child) => child.title == title)
          .firstOrNull;
    }
    return category != null && _hasOfficialBook(category);
  };
}

bool _hasOfficialBook(Category category) =>
    category.books.any((book) => book.source.isOfficial) ||
    category.subCategories.any(_hasOfficialBook);
