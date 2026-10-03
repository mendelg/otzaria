import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/utils/reader_paragraph_copy.dart';

import '../../test_helpers/memory_cache_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  group('buildParagraphCopyText', () {
    test('without headers copies the paragraph as rendered', () async {
      final text = await buildParagraphCopyText(
        processedText: '<b>בראשית</b> ברא',
        index: 0,
        copyWithHeaders: 'none',
        copyHeaderFormat: 'same_line_after_brackets',
        headerBook: TextBook(title: 'ספר בדיקה'),
      );

      expect(text.plainText, 'בראשית ברא');
      expect(text.htmlText, contains('<b>בראשית</b>'));
    });

    test('adds the book name the settings ask for', () async {
      final text = await buildParagraphCopyText(
        processedText: 'בראשית ברא',
        index: 0,
        copyWithHeaders: 'book_name',
        copyHeaderFormat: 'same_line_after_brackets',
        headerBook: TextBook(title: 'ספר בדיקה'),
      );

      expect(text.plainText, 'בראשית ברא (ספר בדיקה)');
    });

    test('adds the path of the paragraph from the book content', () async {
      final text = await buildParagraphCopyText(
        processedText: 'בראשית ברא',
        index: 1,
        copyWithHeaders: 'book_and_path',
        copyHeaderFormat: 'separate_line_before',
        headerBook: TextBook(title: 'ספר בדיקה'),
        bookContent: const ['<h2>פרק א</h2>', 'בראשית ברא'],
      );

      expect(text.plainText, 'ספר בדיקה, פרק א\nבראשית ברא');
    });

    test('without a book there are no headers', () async {
      final text = await buildParagraphCopyText(
        processedText: 'בראשית ברא',
        index: 0,
        copyWithHeaders: 'book_name',
        copyHeaderFormat: 'same_line_after_brackets',
      );

      expect(text.plainText, 'בראשית ברא');
    });
  });
}
