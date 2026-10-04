import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/combined_view/combined_book_screen.dart';
import 'package:otzaria/book_common/selection/selected_text_restore.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';

/// חלון הבחירה נבנה מחדש בכל תזוזת עכבר בגרירה; המטמון חוסך את רינדור
/// השורות החוזר בלי לשנות את התוצאה.
void main() {
  final data = List.generate(
    2100,
    (i) => '<b>וַיֹּאמֶר</b> אֱלֹהִים, יְהִי אוֹר; וַיְהִי־אוֹר. שורה $i',
  );
  const settings = RenderSettings(removeNikud: true);
  final visible = List.generate(30, (i) => 200 + i);

  SelectionWindow window(String Function(int) renderLine) =>
      buildSelectionWindow(
        visibleIndices: visible,
        totalLines: data.length,
        selectionLength: 300,
        renderLine: renderLine,
      );

  test('עדכוני בחירה חוזרים מקבלים את אותן שורות בלי לרנדר מחדש', () {
    final cache = SelectionLineCache();

    final first = window(cache.renderer(data, settings));
    final again = window(cache.renderer(data, settings));

    for (var i = 0; i < first.lines.length; i++) {
      expect(identical(again.lines[i], first.lines[i]), isTrue);
    }
  });

  test('התוצאה זהה לרינדור ללא מטמון', () {
    final cache = SelectionLineCache();
    String direct(int i) =>
        renderSelectionLine(rawText: data[i], settings: settings);

    final expected = window(direct);
    final cachedFirst = window(cache.renderer(data, settings));
    final cachedAgain = window(cache.renderer(data, settings));

    expect(cachedFirst.baseIndex, expected.baseIndex);
    expect(cachedFirst.lines, expected.lines);
    expect(cachedAgain.lines, expected.lines);
  });

  test('שינוי הגדרות או נתונים מרנדר מחדש', () {
    final cache = SelectionLineCache();
    final withoutNikud = cache.renderer(data, settings)(200);

    const keepNikud = RenderSettings();
    expect(
      cache.renderer(data, keepNikud)(200),
      renderSelectionLine(rawText: data[200], settings: keepNikud),
    );
    expect(cache.renderer(data, keepNikud)(200), isNot(withoutNikud));

    final newData = [...data]..[200] = 'טקסט שנטען מחדש';
    expect(cache.renderer(newData, keepNikud)(200), 'טקסט שנטען מחדש');
  });

  test('ניקוי בסוף גרירה מרנדר מחדש', () {
    final cache = SelectionLineCache();
    final before = cache.renderer(data, settings)(200);

    cache.clear();

    final after = cache.renderer(data, settings)(200);
    expect(after, before);
    expect(identical(after, before), isFalse);
  });

  test('מעבר למכסת השורות אינו נשמר', () {
    final cache = SelectionLineCache();
    final render = cache.renderer(data, settings);
    final firstLines = [for (var i = 0; i < data.length; i++) render(i)];

    final again = cache.renderer(data, settings);
    expect(identical(again(0), firstLines[0]), isTrue);
    expect(identical(again(1999), firstLines[1999]), isTrue);
    expect(identical(again(2050), firstLines[2050]), isFalse);
  });
}
