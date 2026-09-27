import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_book_screen.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakePage extends Fake implements PdfPage {
  _FakePage(this.width, this.height);

  @override
  double width;

  @override
  double height;
}

void main() {
  test('מידות זהות — אותו מופע פריסה', () {
    final memo = BookViewLayoutMemo();
    final pages = [for (var i = 0; i < 5; i++) _FakePage(400, 600)];
    final first = memo.layout(pages, hasCover: true, verticalMargin: 16);
    expect(
      memo.layout(List.of(pages), hasCover: true, verticalMargin: 16),
      same(first),
    );
  });

  test('עמוד שנמדד מחדש (אותו אובייקט, מידה אחרת) — פריסה חדשה', () {
    final memo = BookViewLayoutMemo();
    final pages = [for (var i = 0; i < 5; i++) _FakePage(400, 600)];
    final first = memo.layout(pages, hasCover: true, verticalMargin: 16);
    pages[3].height = 700;
    final second = memo.layout(pages, hasCover: true, verticalMargin: 16);
    expect(second, isNot(same(first)));
    expect(second.pageLayouts[3].height, 700);
  });

  test('שינוי כריכה, מרווח או מספר עמודים — פריסה חדשה', () {
    final memo = BookViewLayoutMemo();
    final pages = [for (var i = 0; i < 5; i++) _FakePage(400, 600)];
    final first = memo.layout(pages, hasCover: true, verticalMargin: 16);
    expect(
      memo.layout(pages, hasCover: false, verticalMargin: 16),
      isNot(same(first)),
    );
    final second = memo.layout(pages, hasCover: false, verticalMargin: 8);
    expect(second.pageLayouts, hasLength(5));
    expect(
      memo.layout(pages.sublist(1), hasCover: false, verticalMargin: 8),
      isNot(same(second)),
    );
  });
}
