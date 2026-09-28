import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_content_view.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/widgets/misc/app_selection_area.dart';

/// issue #1271 — בתיבת הריחוף של הערה (עטופה ב-AppSelectionArea) לחיצה ימנית
/// פתחה גם את תפריט ההעתקה של אוצריא וגם את תפריט Flutter של עורך ההערה.
void main() {
  PersonalNote note() => PersonalNote(
    id: 'pn_1',
    bookId: 'Test',
    lineNumber: 1,
    displayTitle: 'כותרת',
    lastKnownLineNumber: null,
    status: PersonalNoteStatus.located,
    content: jsonEncode([
      {'insert': 'תוכן ההערה לבדיקה'},
      {'insert': '\n'},
    ]),
    contentPlain: 'תוכן ההערה לבדיקה',
    contentFormat: PersonalNoteContentFormat.quillDelta,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
  );

  Future<void> rightClickText(WidgetTester tester) async {
    await tester.tapAt(
      tester.getCenter(find.text('תוכן ההערה לבדיקה', findRichText: true)),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('בתוך AppSelectionArea נפתח רק תפריט ההעתקה של אוצריא', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSelectionArea(child: PersonalNoteContentView(note: note())),
        ),
      ),
    );

    await rightClickText(tester);
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('העתק'), findsOneWidget, reason: 'תפריט אוצריא');
    expect(
      find.byType(AdaptiveTextSelectionToolbar),
      findsNothing,
      reason:
          'תפריט Flutter של העורך אסור שיופיע לצד תפריט אוצריא (issue #1271)',
    );
  });

  // בחלונית הצד של ההערות אין מארח עם תפריט, ונפתח תפריט Flutter של העורך
  // במקום תפריט אוצריא (issue #1590).
  testWidgets('בלי AppSelectionArea נפתח תפריט ההעתקה של אוצריא', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PersonalNoteContentView(note: note())),
      ),
    );

    await rightClickText(tester);
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('העתק'), findsOneWidget, reason: 'תפריט אוצריא');
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
  });

  testWidgets('בלי AppSelectionArea "העתק" מעתיק את הטקסט שנבחר בהערה', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PersonalNoteContentView(note: note())),
      ),
    );
    final text = find.text('תוכן ההערה לבדיקה', findRichText: true);
    await tester.tapAt(tester.getCenter(text), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(tester.getCenter(text), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    await rightClickText(tester);
    await tester.tap(find.text('העתק'));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(copied, isNotNull);
    expect('תוכן ההערה לבדיקה', contains(copied!));
    expect(copied, isNotEmpty);
  });

  testWidgets('במגע בלי AppSelectionArea נשאר התפריט הטבעי של העורך', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PersonalNoteContentView(note: note())),
      ),
    );
    debugDefaultTargetPlatformOverride = null;

    expect(find.byType(AppContextMenuRegion), findsNothing);
  });
}
