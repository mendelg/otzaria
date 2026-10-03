import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/models/plugin_context_menu_item.dart';
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

  group('buildReaderPluginMenuEntries', () {
    const items = [
      (
        'plugin.a',
        PluginContextMenuItem(
          id: 'text',
          label: 'בטקסט',
          contexts: ['reader-selection'],
        ),
      ),
      (
        'plugin.b',
        PluginContextMenuItem(
          id: 'page',
          label: 'בצורת הדף',
          contexts: ['reader-page-shape-selection'],
        ),
      ),
    ];

    Future<List<String?>> labels(
      WidgetTester tester, {
      required bool hasSelection,
      String? selectionContext,
      List<(String, PluginContextMenuItem)> pluginItems = items,
      int paragraphIndex = 0,
    }) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      var settingsCalls = 0;
      final entries = buildReaderPluginMenuEntries(
        root: null,
        state: state(),
        lines: lines,
        paragraphIndex: paragraphIndex,
        hasSelection: hasSelection,
        selectedText: hasSelection ? 'שלום' : null,
        anchor: (
          lineStart: null,
          lineEnd: null,
          startColumn: null,
          pointerColumn: null,
        ),
        settings: () {
          settingsCalls++;
          return settings;
        },
        tapPosition: Offset.zero,
        menuContext: context,
        selectionContext: selectionContext ?? 'reader-selection',
        pluginItems: pluginItems,
      );
      if (pluginItems.isEmpty) expect(settingsCalls, 0);
      return [for (final e in entries) e.isDivider ? '---' : e.label];
    }

    testWidgets('a selection shows the items of the given context', (
      tester,
    ) async {
      expect(await labels(tester, hasSelection: true), ['---', 'בטקסט']);
      expect(
        await labels(
          tester,
          hasSelection: true,
          selectionContext: 'reader-page-shape-selection',
        ),
        ['---', 'בצורת הדף'],
      );
    });

    testWidgets('without plugin items or outside the text it is empty', (
      tester,
    ) async {
      expect(
        await labels(tester, hasSelection: true, pluginItems: const []),
        isEmpty,
      );
      expect(
        await labels(tester, hasSelection: true, paragraphIndex: 3),
        isEmpty,
      );
    });

    testWidgets('without a selection only a clicked highlight counts', (
      tester,
    ) async {
      expect(await labels(tester, hasSelection: false), isEmpty);
    });
  });
}
