import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_content_view.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/widgets/misc/app_selection_area.dart';

/// issue #1271 — בתיבת הריחוף של הערה (עטופה ב-AppSelectionArea) לחיצה ימנית
/// פתחה גם את תפריט ההעתקה של אוצריא וגם את תפריט Flutter של עורך ההערה.
void main() {
  const noteText = 'תוכן ההערה לבדיקה';

  PersonalNote note() => PersonalNote(
    id: 'pn_1',
    bookId: 'Test',
    lineNumber: 1,
    displayTitle: 'כותרת',
    lastKnownLineNumber: null,
    status: PersonalNoteStatus.located,
    content: jsonEncode([
      {'insert': noteText},
      {'insert': '\n'},
    ]),
    contentPlain: noteText,
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

  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  void mockClipboard(WidgetTester tester, List<String> writes) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          writes.add((call.arguments as Map)['text'] as String);
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
  }

  Future<void> pumpNote(WidgetTester tester, {bool withSelectionArea = false}) {
    final content = PersonalNoteContentView(note: note());
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: withSelectionArea ? AppSelectionArea(child: content) : content,
        ),
      ),
    );
  }

  testWidgets('בתוך AppSelectionArea נפתח רק תפריט ההעתקה של אוצריא', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      await pumpNote(tester, withSelectionArea: true);

      await rightClickText(tester);

      expect(find.text('העתק'), findsOneWidget, reason: 'תפריט אוצריא');
      expect(
        find.byType(AdaptiveTextSelectionToolbar),
        findsNothing,
        reason:
            'תפריט Flutter של העורך אסור שיופיע לצד תפריט אוצריא (issue #1271)',
      );
    });
  });

  // בחלונית הצד של ההערות אין מארח עם תפריט, ונפתח תפריט Flutter של העורך
  // במקום תפריט אוצריא (issue #1590).
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ]) {
    testWidgets('בלי מארח ב-$platform נפתח רק תפריט ההעתקה של אוצריא', (
      tester,
    ) async {
      await onPlatform(platform, () async {
        await pumpNote(tester);

        await rightClickText(tester);

        expect(find.text('העתק'), findsOneWidget, reason: 'תפריט אוצריא');
        expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      });
    });
  }

  testWidgets('העתקה שומרת בדיוק על טווח הבחירה של Quill', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      final clipboardWrites = <String>[];
      mockClipboard(tester, clipboardWrites);
      await pumpNote(tester);

      final text = find.text(noteText, findRichText: true);
      await tester.tapAt(tester.getCenter(text), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tester.getCenter(text), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      final controller = tester
          .state<quill.QuillEditorState>(find.byType(quill.QuillEditor))
          .controller;
      final selectedText = controller.getPlainText();
      expect(controller.selection.isCollapsed, isFalse);
      expect(selectedText, isNotEmpty);
      expect(selectedText, isNot(noteText));

      await rightClickText(tester);
      await tester.tap(find.text('העתק'));
      await tester.pumpAndSettle();

      expect(clipboardWrites, [selectedText]);
    });
  });

  testWidgets('בחירה ריקה משאירה את "העתק" מושבתת', (tester) async {
    await onPlatform(TargetPlatform.windows, () async {
      final clipboardWrites = <String>[];
      mockClipboard(tester, clipboardWrites);
      await pumpNote(tester);

      await rightClickText(tester);

      final copyLabel = find.text('העתק');
      expect(copyLabel, findsOneWidget);
      final copyButton = tester.widget<MenuItemButton>(
        find.byType(MenuItemButton),
      );
      expect(copyButton.onPressed, isNull);
      await tester.tap(copyLabel);
      await tester.pumpAndSettle();

      expect(clipboardWrites, isEmpty);
    });
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('במגע ב-$platform נשאר תפריט הבחירה הטבעי של העורך', (
      tester,
    ) async {
      await onPlatform(platform, () async {
        await pumpNote(tester);

        final editor = tester.widget<quill.QuillEditor>(
          find.byType(quill.QuillEditor),
        );

        expect(find.byType(AppContextMenuRegion), findsNothing);
        expect(
          editor.config.contextMenuBuilder,
          isNull,
          reason: 'Quill משתמש בתפריט הבחירה הטבעי של הפלטפורמה',
        );
      });
    });
  }
}
