import 'package:flutter/foundation.dart';
import 'package:otzaria/shortcuts/dynamic/dynamic_shortcut.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_display/text_display_exports.dart';

/// בקשת העתקה שמגיעה מקיצור דינמי; המסך שמחזיק את הבחירה מבצע אותה.
@immutable
class DynamicCopyRequest {
  final DynamicShortcutKind kind;
  final TextTarget target;

  /// הפרופיל המלא שבו יש להעתיק (כבר פתור מול ערוץ ההעתקה).
  final TextDisplayProfile profile;

  final bool plainTextOnly;

  const DynamicCopyRequest({
    required this.kind,
    required this.target,
    required this.profile,
    this.plainTextOnly = false,
  });
}

/// מבצע קיצור דינמי על כרטיסיית טקסט. מחזיר false כשאין על מה לפעול.
class DynamicShortcutDispatcher {
  DynamicShortcutDispatcher._();

  static bool run(DynamicShortcut shortcut, TextBookTab tab) {
    final state = tab.bloc.state;
    if (state is! TextBookLoaded) return false;

    switch (shortcut.kind) {
      case DynamicShortcutKind.setTextDisplay:
        final current = state.displayProfile(target: shortcut.target);
        final patch = shortcut.change.patchFor(current);
        if (patch.isEmpty) return false;
        tab.bloc.add(
          ApplyDisplayPatch(
            target: shortcut.target,
            patch: patch,
            persistToBook: shortcut.persistToBook,
          ),
        );
        return true;
      case DynamicShortcutKind.copySelectionWith:
      case DynamicShortcutKind.copyParagraphWith:
        final base = state.displayProfile(
          target: shortcut.target,
          channel: TextChannel.copy,
        );
        tab.dynamicCopyRequestNotifier.value = DynamicCopyRequest(
          kind: shortcut.kind,
          target: shortcut.target,
          profile: shortcut.change.patchFor(base).applyTo(base),
          plainTextOnly: shortcut.plainTextOnly,
        );
        return true;
    }
  }
}
