import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/core/messages/common_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/text_book/view/selection/selection_hit_test.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/widgets/text/rtl_selection_shortcuts.dart';
import 'package:otzaria/widgets/text/selection_copy_shortcuts.dart';

/// אזור בחירת טקסט שמציג בלחיצה ימנית את תפריט ההקשר של אוצריא
/// (במקום תפריט ברירת המחדל של Flutter). לתוכן קריא כללי —
/// דיאלוגים, חלוניות וכותרות.
class AppSelectionArea extends StatefulWidget {
  const AppSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<AppSelectionArea> createState() => AppSelectionAreaState();

  static AppSelectionAreaState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AppSelectionAreaState>();
}

class AppSelectionAreaState extends State<AppSelectionArea> {
  String? _selectedText;
  final _selectionSources = <String Function()>{};

  /// תוכן שמנהל בחירה משלו (עורך Quill) ואינו מדווח ל-SelectionArea — בלי
  /// הרישום "העתק" לא רואה את מה שסומן בו.
  void addSelectionSource(String Function() source) =>
      _selectionSources.add(source);

  void removeSelectionSource(String Function() source) =>
      _selectionSources.remove(source);

  bool get _hasSelection =>
      _selectedText != null && _selectedText!.trim().isNotEmpty;

  String? get _textToCopy {
    if (_hasSelection) return _selectedText;
    for (final source in _selectionSources) {
      final text = source();
      if (text.trim().isNotEmpty) return text;
    }
    return null;
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    UiSnack.show(CommonMessages.textCopiedShort);
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final useNativeTouchMenu =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return SelectionCutFallthrough(
      child: RtlSelectionShortcuts(
        child: SelectionArea(
          contextMenuBuilder: useNativeTouchMenu
              ? (context, state) =>
                    AdaptiveTextSelectionToolbar.selectableRegion(
                      selectableRegionState: state,
                    )
              : (context, _) => const SizedBox.shrink(),
          onSelectionChanged: (selection) {
            trackRtlSelection(selection?.plainText);
            // שינוי בחירה זמני בזמן priming (קיצורי RTL) — לא לעבד.
            if (rtlSelectionPriming) return;
            _selectedText = selection?.plainText;
          },
          child: AppContextMenuRegion(
            openOnLongPress: !useNativeTouchMenu,
            // לחיצה ימנית על הטקסט המסומן לא תשחרר את הבחירה (ברירת המחדל של
            // SelectableRegion ב-Windows); לחיצה מחוץ לבחירה מבטלת כרגיל.
            shouldPreserveSelectionOnSecondaryTap: (globalPosition) {
              if (!_hasSelection) return false;
              final root = context.findRenderObject();
              if (root == null) return true;
              return clickIsOnSelectionWithinArea(
                    root: root,
                    globalPosition: globalPosition,
                    selectedText: _selectedText!,
                  ) ??
                  true;
            },
            menuBuilder: (menuContext, _) {
              final text = _textToCopy;
              return [
                AppContextMenuEntry(
                  label: 'העתק',
                  icon: FluentIcons.copy_24_regular,
                  enabled: text != null,
                  onTap: () => _copy(text!),
                ),
              ];
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
