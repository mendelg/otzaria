import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/utils/reader_plugin_menu_entries.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  const lines = ['שלום עולם', 'עולם ומלואו', 'שלום לכולם'];
  const settings = RenderSettings(formatParentheses: false);

  TextBookLoaded state() => TextBookLoaded(
    book: TextBook(title: 'ספר בדיקה', id: 7),
    showLeftPane: false,
    content: lines,
    fontSize: 18,
    showSplitView: false,
    activeCommentators: const [],
    commentatorGroups: const [],
    availableCommentators: const [],
    links: const [],
    visibleLinks: const [],
    linksByLine: const {},
    tableOfContents: const [],
    removeNikud: false,
    visibleIndices: const [0],
    selectedIndex: null,
    pinLeftPane: false,
    searchText: '',
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );

  group('buildReaderSelectionPayload', () {
    test('anchors a selection in the paragraph where it starts', () {
      final payload = buildReaderSelectionPayload(
        state: state(),
        lines: lines,
        paragraphIndex: 2,
        selectedText: 'עולם',
        anchor: (lineStart: 1, lineEnd: 1, startColumn: 0, pointerColumn: 8),
        settings: settings,
      );

      expect(payload['currentIndex'], 1);
      expect(payload['text'], 'עולם');
      expect(payload['id'], 7);
      expect(payload.containsKey('sections'), isFalse);
    });

    test('falls back to the clicked paragraph without a tracked start', () {
      final payload = buildReaderSelectionPayload(
        state: state(),
        lines: lines,
        paragraphIndex: 2,
        selectedText: 'שלום',
        anchor: (
          lineStart: null,
          lineEnd: null,
          startColumn: null,
          pointerColumn: null,
        ),
        settings: settings,
      );

      expect(payload['currentIndex'], 2);
    });

    test('gives a selection over paragraphs one anchor per paragraph', () {
      final payload = buildReaderSelectionPayload(
        state: state(),
        lines: lines,
        paragraphIndex: 0,
        selectedText: 'עולם\nעולם ומלואו',
        anchor: (lineStart: 0, lineEnd: 1, startColumn: 5, pointerColumn: 5),
        settings: settings,
      );

      expect(payload['currentIndex'], 0);
      final sections = payload['sections'] as List;
      expect([for (final s in sections) s['currentIndex']], [0, 1]);
    });
  });
}
