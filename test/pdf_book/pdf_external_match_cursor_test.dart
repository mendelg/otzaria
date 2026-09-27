import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_external_matches_bar.dart';

/// "הבא"/"הקודם" בסרגל ההתאמות ממשיכים מהעמוד שבקורא, גם אחרי גלילה ידנית.
void main() {
  const pages = [3, 8, 15];

  test('על עמוד התאמה — היא עצמה, והשכנות משני צדיה', () {
    expect(externalMatchCursor(pages, 8), (exact: 1, previous: 0, next: 2));
  });

  test('בין התאמות — הקרובה לפני ואחרי', () {
    expect(
      externalMatchCursor(pages, 10),
      (exact: null, previous: 1, next: 2),
    );
  });

  test('לפני הראשונה ואחרי האחרונה', () {
    expect(
      externalMatchCursor(pages, 1),
      (exact: null, previous: null, next: 0),
    );
    expect(
      externalMatchCursor(pages, 20),
      (exact: null, previous: 2, next: null),
    );
    expect(externalMatchCursor(pages, 15), (exact: 2, previous: 1, next: null));
  });
}
