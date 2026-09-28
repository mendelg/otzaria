import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/utils/pdf_render_scale.dart';

const _threshold = 200 / 72;

double _scale(
  double displayScale, {
  double width = 595,
  double height = 842,
}) => pdfPreviewRenderingScale(
  displayScale: displayScale,
  threshold: _threshold,
  pageWidth: width,
  pageHeight: height,
  sizeThreshold: 2000,
);

void main() {
  group('pdfPreviewRenderingScale', () {
    test('מסך רגיל בהתאמה לרוחב — חזקת 2 שמעל הרזולוציה המוצגת', () {
      expect(_scale(1.3), 2.0);
      expect(_scale(0.9), 1.0);
      expect(_scale(1.0), 1.0);
    });

    test('זום קטן בתוך אותה מדרגה אינו משנה את קנה המידה', () {
      expect(_scale(1.1), _scale(1.9));
    });

    test('לעולם לא מעל התקרה של pdfrx', () {
      expect(_scale(2.5), _threshold);
      expect(_scale(8), _threshold);
    });

    test('עמוד גדול מ-2000pt מוגבל ל-2000px כמו ב-pdfrx', () {
      expect(2400 * _scale(8, width: 1700, height: 2400), closeTo(2000, 1e-9));
    });

    test('סריקה גדולה בזום נמוך — לפי המוצג ולא 200DPI', () {
      // לפני: 1999pt ב-200DPI ≈ 5550px בכל זום. כעת בהתאמה לרוחב ב-1080p ≈ 1000px.
      expect(1999 * _scale(0.45, width: 1400, height: 1999), closeTo(999.5, 1));
    });

    test('ערך לא תקין חוזר לתקרה', () {
      expect(_scale(0), _threshold);
      expect(_scale(double.nan), _threshold);
    });

    test('זום מוקטן (תצוגת ספר, הרבה עמודים) מקטין את התמונה', () {
      expect(_scale(0.3), 0.5);
    });
  });
}
