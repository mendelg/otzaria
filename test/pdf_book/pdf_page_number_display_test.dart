import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_page_number_display.dart';
import 'package:pdfrx/pdfrx.dart';

/// מדמה את המלכוד ב-pdfrx: `pageNumber` של ה-controller מתעדכן רק ב-build
/// שאחרי שינוי המטריצה, והמאזינים שלו מקבלים ערך ישן.
class _StaleController extends PdfViewerController {
  _StaleController({this.page = 1});

  final int page;

  @override
  bool get isReady => true;

  @override
  int? get pageNumber => page;

  @override
  int get pageCount => 125;
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(appBar: AppBar(title: child)),
);

void main() {
  testWidgets(
    'onPageChanged מרענן את המונה בלי אינטראקציה נוספת',
    (tester) async {
      final notifier = ValueNotifier<int?>(null);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _wrap(
          PageNumberDisplay(
            controller: _StaleController(),
            pageNumberNotifier: notifier,
          ),
        ),
      );

      expect(find.text('1/125'), findsOneWidget);

      // כמו ב-pdfrx: רק onPageChanged יורה, ה-controller נשאר תקוע על 1
      // ואינו מודיע למאזיניו.
      notifier.value = 2;
      await tester.pump();

      expect(
        find.text('2/125'),
        findsOneWidget,
        reason: 'המונה חייב לעקוב אחרי onPageChanged, לא אחרי pageNumber הישן',
      );
      expect(find.text('1/125'), findsNothing);
    },
  );

  testWidgets('בלי notifier נופלים חזרה ל-pageNumber של ה-controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(PageNumberDisplay(controller: _StaleController(page: 7))),
    );

    expect(find.text('7/125'), findsOneWidget);
  });

  testWidgets('הזנת עמוד עוברת בניווט של המסך (שומר זום), מוגבלת לטווח', (
    tester,
  ) async {
    final requested = <int>[];
    await tester.pumpWidget(
      _wrap(
        PageNumberDisplay(
          controller: _StaleController(page: 3),
          onNavigateToPage: (page) async => requested.add(page),
        ),
      ),
    );

    await tester.tap(find.text('3/125'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(find.byType(TextField), '400');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(requested, [125]);
  });

  testWidgets('לפני העמוד הראשון שדווח, ה-controller הוא המקור', (
    tester,
  ) async {
    final notifier = ValueNotifier<int?>(null);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      _wrap(
        PageNumberDisplay(
          controller: _StaleController(page: 3),
          pageNumberNotifier: notifier,
        ),
      ),
    );

    expect(find.text('3/125'), findsOneWidget);
  });
}
