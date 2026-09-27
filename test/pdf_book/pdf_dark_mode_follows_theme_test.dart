import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// היפוך הצבעים של ה-PDF חייב להיגזר מבהירות התמה בפועל: הדגל השמור
/// `isDarkMode` נשאר על ערכו הישן במצב "מערכת", וה-PDF נתקע כהה (issue #1426).
void main() {
  final lines = File(
    'lib/pdf_book/view/pdf_book_screen.dart',
  ).readAsLinesSync();
  final code = lines
      .where((line) => !line.trimLeft().startsWith('//'))
      .toList();

  test('אין צרכן של SettingsState.isDarkMode במסך ה-PDF', () {
    expect(code.join('\n'), isNot(contains('.state.isDarkMode')));
  });

  test('כל היפוך צבעים נגזר מ-Theme.of(context).brightness', () {
    final source = code.join('\n');
    final calls = RegExp(r'pdfPageColor(?:Filter)?\(').allMatches(source);
    final themed = RegExp(
      r'pdfPageColor(?:Filter)?\(\s*(?:Theme\.of\(context\)\.brightness|brightness)\s*[,)]',
    ).allMatches(source);
    expect(calls, isNotEmpty);
    expect(themed.length, calls.length);
    expect(
      source,
      contains('final brightness = Theme.of(context).brightness;'),
    );
  });
}
