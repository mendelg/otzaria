import 'package:otzaria/book_common/selection/selected_text_restore.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/plugins/services/reader_selection_service.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';

/// Where the reader's current selection sits in the book's lines.
typedef ReaderSelectionAnchor = ({
  int? lineStart,
  int? lineEnd,
  int? startColumn,
  int? pointerColumn,
});

/// The selection payload that plugins receive for a selection in the main
/// text of a reader view, whose lines are [lines].
///
/// A selection over several paragraphs gets one anchor per paragraph. A
/// selection within one paragraph is anchored in the paragraph where it
/// starts, not in [paragraphIndex] where the user clicked; otherwise a phrase
/// that also appears in the clicked paragraph would take the anchor.
Map<String, dynamic> buildReaderSelectionPayload({
  required TextBookLoaded state,
  required List<String> lines,
  required int paragraphIndex,
  required String selectedText,
  required ReaderSelectionAnchor anchor,
  required RenderSettings settings,
}) {
  const selectionService = ReaderSelectionService();
  final book = state.book;
  final lineStart = anchor.lineStart;
  final lineEnd = anchor.lineEnd;
  if (lineStart != null &&
      lineEnd != null &&
      lineEnd > lineStart &&
      lineStart >= 0 &&
      lineEnd < lines.length) {
    final rawTexts = [for (var i = lineStart; i <= lineEnd; i++) lines[i]];
    final renderedLines = [
      for (final raw in rawTexts)
        renderSelectionLine(rawText: raw, settings: settings),
    ];
    return selectionService.buildMultiSectionPayload(
      bookId: book.title,
      bookTitle: book.title,
      firstSectionIndex: lineStart,
      rawTexts: rawTexts,
      lineRanges:
          locateSelectionRangesPerLine(
            selectedText: selectedText,
            visibleLines: renderedLines,
            startColumnHint: anchor.startColumn,
          ) ??
          const [],
      settings: settings,
      selectedText: selectedText,
      currentRef: state.currentTitle,
      bookDbId: book.id,
      bookType: PluginBookIdentity.typeOf(book),
      bookSource: PluginBookIdentity.sourceOf(book),
    );
  }

  final sectionIndex =
      (lineStart != null && lineStart >= 0 && lineStart < lines.length)
      ? lineStart
      : paragraphIndex;
  final renderedLine = renderSelectionLine(
    rawText: lines[sectionIndex],
    settings: settings,
  );
  final localRange = selectionService.locateRenderedRange(
    renderedText: renderedLine,
    selectedText: selectedText,
    startHint: sectionIndex == paragraphIndex
        ? (anchor.pointerColumn ?? anchor.startColumn)
        : anchor.startColumn,
  );
  return selectionService.buildPayload(
    bookId: book.title,
    bookTitle: book.title,
    sectionIndex: sectionIndex,
    rawText: lines[sectionIndex],
    settings: settings,
    selectedText: selectedText,
    renderedStartUtf16: localRange?.start,
    renderedEndUtf16: localRange?.end,
    currentRef: state.currentTitle,
    bookDbId: book.id,
    bookType: PluginBookIdentity.typeOf(book),
    bookSource: PluginBookIdentity.sourceOf(book),
    bookUid: PluginBookIdentity.uidOf(book),
  );
}
