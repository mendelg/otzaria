import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:otzaria/book_common/models/commentator_group.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';

/// פריט "פתח את חלונית המפרשים" יוצג כשיש מפרשים נבחרים, המפרשים אינם מוצגים
/// inline מתחת לטקסט, וטאב המפרשים אינו כבר פעיל בחלונית הצד.
bool shouldShowOpenCommentatorsPaneEntry({
  required bool hasSelectedCommentators,
  required bool showCommentaryAsExpansionTiles,
  required bool isCommentatorsTabActive,
}) {
  return hasSelectedCommentators &&
      !showCommentaryAsExpansionTiles &&
      !isCommentatorsTabActive;
}

/// פריט "בחר מפרשים מרובים" יוצג כשיש callback לפתיחת חלונית הסינון וטאב
/// המפרשים אינו פעיל בחלונית הצד.
///
/// בניגוד ל-[shouldShowOpenCommentatorsPaneEntry], הפריט הזה לא תלוי
/// ב-`hasSelectedCommentators` — מטרתו לאפשר בחירה גם כשהבחירה ריקה.
bool shouldShowSelectCommentatorsEntry({
  required bool hasOpenCommentatorsPaneWithFilterCallback,
  required bool isCommentatorsTabActive,
}) {
  return hasOpenCommentatorsPaneWithFilterCallback && !isCommentatorsTabActive;
}

/// נקרא כשבחירת המפרשים משתנה מתוך תת-התפריט.
///
/// [commentators] - הבחירה המעודכנת המלאה.
/// [isAdding] - האם הפעולה הוסיפה מפרשים (ולכן כדאי לפתוח את החלונית).
typedef CommentatorsSelectionChanged =
    void Function(List<String> commentators, {required bool isAdding});

/// בונה את פריטי תת-התפריט "מפרשים על פסקה זו" בתפריט ההקשר של גוף הספר.
///
/// משותף לתצוגה המשולבת/מפוצלת ולצורת הדף, כדי ששלושתן יציגו את אותם פריטים
/// ואותה התנהגות. [availableCommentators] הם מפרשי הפסקה בלבד (ראו
/// [paragraphCommentators]); הקבוצות מסוננות לפיהם.
///
/// [onOpenPane] ו-[onSelectMultiple] אינם מוצגים כשהם `null`. כשאין מפרשים
/// לפסקה מוחזר רק פריט "טוען…" מושבת בזמן [linksLoading], ואחריו
/// רשימה ריקה — כך הפריט האב מתאפר (issue #1413).
List<AppContextMenuEntry> buildCommentatorsContextMenuChildren({
  required List<String> activeCommentators,
  required List<String> availableCommentators,
  required List<CommentatorGroup> commentatorGroups,
  required CommentatorsSelectionChanged onCommentatorsChanged,
  VoidCallback? onOpenPane,
  VoidCallback? onSelectMultiple,
  bool linksLoading = false,
}) {
  final activeSet = activeCommentators.toSet();
  final availableSet = availableCommentators.toSet();
  final allActive = activeSet.containsAll(availableCommentators);

  List<AppContextMenuEntry> buildGroup(CommentatorGroup group) {
    final commentators = group.commentators.where(availableSet.contains);
    if (commentators.isEmpty) return const <AppContextMenuEntry>[];
    final groupActive = commentators.every(activeSet.contains);
    return [
      AppContextMenuEntry(
        label: 'הצג את כל ${group.title}',
        isSelected: groupActive,
        onTap: () {
          final updated = List<String>.from(activeCommentators);
          if (groupActive) {
            updated.removeWhere(commentators.contains);
          } else {
            for (final title in commentators) {
              if (!updated.contains(title)) updated.add(title);
            }
          }
          onCommentatorsChanged(updated, isAdding: !groupActive);
        },
      ),
      ...commentators.map((title) {
        final isActive = activeSet.contains(title);
        return AppContextMenuEntry(
          label: title,
          isSelected: isActive,
          onTap: () {
            // מפרש פעיל אינו מוסר מכאן — לחיצה עליו רק פותחת את החלונית.
            // הסרה שקטה גרמה ללולאת הוסף/הסר בכל ניסיון חוזר (issue #904).
            final updated = List<String>.from(activeCommentators);
            if (!isActive) updated.add(title);
            onCommentatorsChanged(updated, isAdding: true);
          },
        );
      }),
    ];
  }

  if (availableCommentators.isEmpty) {
    return linksLoading
        ? const [AppContextMenuEntry(label: 'טוען מפרשים…', enabled: false)]
        : const <AppContextMenuEntry>[];
  }

  final entries = <AppContextMenuEntry>[
    if (onOpenPane != null)
      AppContextMenuEntry(
        label: 'פתח את חלונית המפרשים',
        icon: FluentIcons.panel_right_24_regular,
        isHighlighted: true,
        onTap: onOpenPane,
      ),
    if (onSelectMultiple != null)
      AppContextMenuEntry(
        label: 'בחר מפרשים מרובים',
        icon: FluentIcons.filter_24_regular,
        isHighlighted: true,
        onTap: onSelectMultiple,
      ),
    if (onOpenPane != null || onSelectMultiple != null)
      const AppContextMenuEntry.divider(),
    AppContextMenuEntry(
      label: 'הצג את כל המפרשים על פסקה זו',
      isSelected: allActive,
      onTap: () => onCommentatorsChanged(
        allActive ? <String>[] : List<String>.from(availableCommentators),
        isAdding: !allActive,
      ),
    ),
  ];

  // הקבוצות מגיעות מה-BLoC כשהן כבר ממוינות לפי דורות; מפריד מתווסף רק לפני
  // קבוצה שיש בה מפרשים, כדי שקבוצה ריקה באמצע לא תדביק שתי קבוצות זו לזו.
  for (final group in commentatorGroups) {
    final items = buildGroup(group);
    if (items.isEmpty) continue;
    entries.add(const AppContextMenuEntry.divider());
    entries.addAll(items);
  }

  return entries;
}

/// The entry that opens the links pane is shown when there are links and
/// the links tab of the side pane is not already active.
bool shouldShowOpenLinksPaneEntry({
  required bool hasLinks,
  required bool isLinksTabActive,
}) {
  return hasLinks && !isLinksTabActive;
}
