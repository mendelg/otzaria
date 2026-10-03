import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/utils/text/global_search_helper.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria/widgets/misc/app_popup_menu.dart';
import 'package:otzaria/widgets/misc/direct_link_menu_entries.dart';
import 'package:otzaria/widgets/misc/link_context_menu_entry.dart';
import 'package:otzaria_icons/otzaria_icons.dart';

/// The selected text as a reader's context menu searches for it: trimmed
/// and without nikud or teamim, since search always ignores them.
class ReaderMenuSelection {
  ReaderMenuSelection(String? selectedText) : cleaned = _clean(selectedText);

  final String cleaned;

  bool get hasText => cleaned.isNotEmpty;

  /// [cleaned] cut to [maxChars] graphemes, for labels and tooltips.
  String quote(int maxChars) {
    final chars = cleaned.characters;
    return chars.length > maxChars ? '${chars.take(maxChars)}...' : cleaned;
  }

  static String _clean(String? text) {
    final raw = text?.trim() ?? '';
    return utils.hasNikud(raw) ? utils.removeVolwels(raw).trim() : raw;
  }
}

/// The icon row at the top of a reader's main text context menu: search all
/// books, copy, add a note and, for a book in the library, copy a link.
AppContextMenuEntry buildReaderIconRow({
  required BuildContext context,
  required ReaderMenuSelection selection,
  required Book book,
  required int paragraphIndex,
  required String? selectedText,
  required VoidCallback onCopy,
  required VoidCallback onAddNote,
}) {
  final bookId = book.id;
  return AppContextMenuEntry.iconRow([
    AppContextMenuIconAction(
      label: 'חיפוש',
      tooltip: selection.hasText
          ? 'חיפוש "${selection.quote(14)}" בכל הספרים'
          : 'חיפוש בכל הספרים',
      icon: FluentIcons.library_24_regular,
      enabled: selection.hasText,
      onTap: () =>
          openGlobalSearch(context, selection.cleaned, insertAdjacent: true),
    ),
    AppContextMenuIconAction(
      label: 'העתקה',
      icon: FluentIcons.copy_24_regular,
      enabled: selection.hasText,
      onTap: onCopy,
    ),
    AppContextMenuIconAction(
      label: 'הערה',
      icon: FluentIcons.note_add_24_regular,
      onTap: onAddNote,
    ),
    if (bookId != null)
      AppContextMenuIconAction(
        label: 'קישור',
        icon: OtzariaIcons.link_copy_24_regular,
        submenuBuilder: () => buildDirectLinkSubmenuActions(
          bookId: bookId,
          source: book.source,
          index: paragraphIndex,
          selectedText: selectedText,
        ),
      ),
  ]);
}

/// The children of a paragraph's "קישורים" submenu: [openPaneEntry], when
/// given, then one entry per link. While the links of the paragraph are
/// still loading and none is known yet, a disabled "loading" entry.
List<AppContextMenuEntry> buildParagraphLinksMenuChildren({
  required List<Link> links,
  required bool isLoading,
  required bool removeNikud,
  required bool removePunctuation,
  required double maxFontSize,
  required void Function(Link link) onOpenLink,
  AppContextMenuEntry? openPaneEntry,
}) {
  if (links.isEmpty) {
    return isLoading
        ? const [AppContextMenuEntry(label: 'טוען קישורים…', enabled: false)]
        : const <AppContextMenuEntry>[];
  }
  return [
    if (openPaneEntry != null) ...[
      openPaneEntry,
      const AppContextMenuEntry.divider(),
    ],
    for (final link in links)
      buildLinkContextMenuEntry(
        link: link,
        removeNikud: removeNikud,
        removePunctuation: removePunctuation,
        maxFontSize: maxFontSize,
        onTap: () => onOpenLink(link),
      ),
  ];
}
