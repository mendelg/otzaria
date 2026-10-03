import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/utils/reader_menu_entries.dart';

void main() {
  group('ReaderMenuSelection', () {
    test('trims the selection and drops nikud', () {
      final selection = ReaderMenuSelection('  בְּרֵאשִׁית ');
      expect(selection.cleaned, 'בראשית');
      expect(selection.hasText, isTrue);
    });

    test('a missing or blank selection has no text', () {
      expect(ReaderMenuSelection(null).hasText, isFalse);
      expect(ReaderMenuSelection('  ').hasText, isFalse);
    });

    test('quotes up to the given number of characters', () {
      final selection = ReaderMenuSelection('בראשית ברא אלהים');
      expect(selection.quote(6), 'בראשית...');
      expect(selection.quote(40), 'בראשית ברא אלהים');
    });
  });

  group('buildReaderIconRow', () {
    Future<List<String>> describe(
      WidgetTester tester, {
      required String? selectedText,
      int? bookId,
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
      final row = buildReaderIconRow(
        context: context,
        selection: ReaderMenuSelection(selectedText),
        book: TextBook(title: 'ספר בדיקה', id: bookId),
        paragraphIndex: 0,
        selectedText: selectedText,
        onCopy: () {},
        onAddNote: () {},
      );
      return [
        for (final action in row.iconRowActions!)
          '${action.label}${action.enabled ? '' : ' (disabled)'}',
      ];
    }

    testWidgets('search and copy need a selection', (tester) async {
      expect(await describe(tester, selectedText: null), [
        'חיפוש (disabled)',
        'העתקה (disabled)',
        'הערה',
      ]);
      expect(await describe(tester, selectedText: 'שלום'), [
        'חיפוש',
        'העתקה',
        'הערה',
      ]);
    });

    testWidgets('a book in the library adds the link action', (tester) async {
      expect(await describe(tester, selectedText: null, bookId: 7), [
        'חיפוש (disabled)',
        'העתקה (disabled)',
        'הערה',
        'קישור',
      ]);
    });
  });
}
