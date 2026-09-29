import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/models/alt_toc_structure.dart';
import 'package:otzaria/text_book/view/alt_toc_sidebar_view.dart';

AltTocStructure _s(int id, String key) =>
    AltTocStructure(id: id, bookId: 1, key: key);

List<String> _keys(List<AltTocStructure> structures) => [
  for (final s in structures) s.key,
];

void main() {
  test('SimanNames לפני Seifim, אף שהמזהה שלו גדול יותר', () {
    final ordered = sidebarStructureOrder([
      _s(10, 'Seifim'),
      _s(11, 'SimanNames'),
    ]);

    expect(_keys(ordered), ['SimanNames', 'Seifim']);
  });

  test('SimanNames לפני Topic, ושאר המבנים שומרים על סדרם', () {
    final ordered = sidebarStructureOrder([
      _s(1, 'Topic'),
      _s(2, 'Parasha'),
      _s(3, 'SimanNames'),
      _s(4, 'Daf'),
    ]);

    expect(_keys(ordered), ['SimanNames', 'Topic', 'Parasha', 'Daf']);
  });

  test('בלי SimanNames — הסדר לא משתנה', () {
    final input = [_s(5, 'Daf'), _s(2, 'Topic')];

    expect(sidebarStructureOrder(input), input);
  });
}
