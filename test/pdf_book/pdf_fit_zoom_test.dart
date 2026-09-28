import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_book_screen.dart';

void main() {
  test('עמוד גבוה — הרוחב קובע את ההתאמה לרוחב, הגובה את העמוד השלם', () {
    final fits = pdfFitZooms(
      shown: const Rect.fromLTWH(0, 0, 600, 800),
      viewSize: const Size(1216, 816),
      margin: 8,
    );
    expect(fits.width, closeTo(2.0, 1e-9));
    expect(fits.page, closeTo(1.0, 1e-9));
  });

  test('עמוד שנכנס לרוחב לפני הגובה — שתי ההתאמות זהות', () {
    final fits = pdfFitZooms(
      shown: const Rect.fromLTWH(0, 0, 1000, 200),
      viewSize: const Size(1016, 816),
      margin: 8,
    );
    expect(fits.page, fits.width);
  });

  test('המתג עובר לעמוד שלם רק מהתאמה לרוחב', () {
    expect(pdfNextFitIsPage(zoom: 2.0, widthZoom: 2.0), isTrue);
    expect(pdfNextFitIsPage(zoom: 2.01, widthZoom: 2.0), isTrue);
    expect(pdfNextFitIsPage(zoom: 1.0, widthZoom: 2.0), isFalse);
    expect(pdfNextFitIsPage(zoom: 3.0, widthZoom: 2.0), isFalse);
  });
}
