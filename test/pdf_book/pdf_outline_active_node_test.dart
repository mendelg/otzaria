import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_outlines_screen.dart';
import 'package:pdfrx/pdfrx.dart';

PdfOutlineNode _node(String title, int? page, [List<PdfOutlineNode>? kids]) =>
    PdfOutlineNode(
      title: title,
      dest: page == null ? null : PdfDest(page, PdfDestCommand.fit, null),
      children: kids ?? const [],
    );

void main() {
  final outline = [
    _node('הקדמה', 1),
    _node('פרק א', 5, [_node('סעיף א', 5), _node('סעיף ב', 9)]),
    _node('פרק ב', 20),
  ];

  test('עמוד באמצע סעיף — הסעיף שהתחיל לפניו מודגש', () {
    expect(pdfOutlineActiveNode(outline, 12)?.title, 'סעיף ב');
    expect(pdfOutlineActiveNode(outline, 3)?.title, 'הקדמה');
  });

  test('עמוד שבו מתחיל סעיף — הסעיף העמוק ביותר', () {
    expect(pdfOutlineActiveNode(outline, 5)?.title, 'סעיף א');
    expect(pdfOutlineActiveNode(outline, 25)?.title, 'פרק ב');
  });

  test('לפני הסעיף הראשון — אין סעיף פעיל', () {
    expect(
      pdfOutlineActiveNode([_node('פרק א', 4)], 2),
      isNull,
    );
  });

  test('סעיף בלי יעד לא עוצר את הסריקה של אחיו', () {
    final withHole = [
      _node('פרק א', 1),
      _node('כותרת בלי יעד', null),
      _node('פרק ב', 10),
    ];
    expect(pdfOutlineActiveNode(withHole, 12)?.title, 'פרק ב');
  });
}
