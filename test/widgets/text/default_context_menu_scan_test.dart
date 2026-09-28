import 'dart:io';

import 'package:test/test.dart';

/// בחירת טקסט ב-lib מציגה את תפריט אוצריא ולא את תפריט Flutter (issue #1590).
///
/// `SelectableText` פותח את תפריט Flutter גם בתוך AppSelectionArea, ו-SelectionArea
/// בלי `contextMenuBuilder` מציג את תפריט ברירת המחדל.
void main() {
  const wrapper = 'lib/widgets/misc/app_selection_area.dart';

  List<String> scan(bool Function(List<String> lines, int i) isHit) {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.uri.path == wrapper) continue;
      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (isHit(lines, i)) {
          hits.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    return hits;
  }

  test('אין SelectableText ב-lib', () {
    final hits = scan(
      (lines, i) => RegExp(r'\bSelectableText(\.rich)?\(').hasMatch(lines[i]),
    );
    expect(
      hits,
      isEmpty,
      reason: 'יש להשתמש ב-Text בתוך AppSelectionArea:\n${hits.join('\n')}',
    );
  });

  test('כל SelectionArea ו-SelectableRegion מגדירים contextMenuBuilder', () {
    final hits = scan((lines, i) {
      if (!RegExp(r'\b(SelectionArea|SelectableRegion)\(').hasMatch(lines[i])) {
        return false;
      }
      if (lines[i].contains('AppSelectionArea(')) return false;
      final end = i + 15 < lines.length ? i + 15 : lines.length;
      return !lines
          .sublist(i, end)
          .any((l) => l.contains('contextMenuBuilder'));
    });
    expect(
      hits,
      isEmpty,
      reason: 'יש להשתמש ב-AppSelectionArea:\n${hits.join('\n')}',
    );
  });
}
