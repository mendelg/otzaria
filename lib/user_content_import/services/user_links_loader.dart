import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/user_books_database_holder.dart';
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/models/link_types.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/user_content_import/repository/user_content_repository.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;

/// טוען קישורי-משתמש (מ-user_books.db) ככ-[Link] עבור ספר שנקרא, בשני
/// הכיוונים:
/// - forward: ספר-המשתמש מקושר ליעד (כשקוראים את ספר-המשתמש עצמו).
/// - inverse: ספר-משתמש אחר מצביע אל הספר הזה (כשקוראים רשמי/אישי שעליו
///   נכתב מפרש-משתמש) — כך מפרש-משתמש מופיע גם בספר הרשמי.
///
/// מחזיר רשימה ריקה אם user_books.db לא פתוח (בלי לכפות פתיחתו), או לספר
/// ממסד מצורף — טבלת user_link מבחינה רק בין רשמי לאישי.
Future<List<Link>> loadUserLinksForBook({
  required String bookTitle,
  required int? bookCategoryId,
  required BookSource source,
  required int startLineIndex,
  required int endLineIndex,
  List<String>? targetBookTitles,
}) async {
  if (source.isAttached) return const [];
  final repo = UserBooksDatabaseHolder.instance.repositoryIfInitialized;
  if (repo == null) return const [];
  final isUserBook = source.isUser;

  final ucr = UserContentRepository(repo.database);
  final result = <Link>[];

  // forward — קישורים היוצאים מהספר הנקרא (אישי או רשמי).
  final forward = await ucr.forwardUserLinks(
    bookTitle,
    sourceIsUserBook: isUserBook,
    sourceCategoryId: bookCategoryId,
    startLineIndex: startLineIndex,
    endLineIndex: endLineIndex,
  );
  for (final r in forward) {
    final targetLine = r.targetLineIndex;
    // ללא יעד-שורה אין לאן לפתוח (index2==0 נכשל כ-"Invalid link reference").
    if (targetLine == null) continue;
    result.add(
      Link(
        heRef: r.targetRef ?? r.targetTitle,
        index1: r.sourceLineIndex + 1,
        path2: r.targetTitle,
        index2: targetLine + 1,
        connectionType: r.connectionType,
        targetCategoryId: r.targetCategoryId,
        targetSource: BookSource.fromUserFlag(r.targetIsUserBook),
        anchorStart: r.anchorStart,
        anchorEnd: r.anchorEnd,
        // אופסטי user_link נכתבים כפי שהלינקר מדד אותם — על ה-HTML הגולמי,
        // ולא במוסכמת התווים-הגלויים של link_anchor שב-seforim.db.
        anchorOffsetsAreRaw: true,
        anchorLabel: r.anchorLabel,
        heRefEnd: r.targetRefEnd,
        index2End: r.targetLineIndexEnd == null
            ? null
            : r.targetLineIndexEnd! + 1,
      ),
    );
  }

  // inverse — קישור-משתמש שמצביע אל הספר הנקרא; פתיחתו חוזרת אל ספר המקור
  // (אישי או רשמי, לפי sourceIsUserBook).
  final inverse = await ucr.inverseUserLinks(
    bookTitle,
    targetIsUserBook: isUserBook,
    targetCategoryId: bookCategoryId,
    startLineIndex: startLineIndex,
    endLineIndex: endLineIndex,
  );
  for (final r in inverse) {
    final targetLine = r.targetLineIndex;
    if (targetLine == null) continue;
    result.add(
      Link(
        heRef: r.sourceTitle,
        index1: targetLine + 1,
        path2: r.sourceTitle,
        index2: r.sourceLineIndex + 1,
        // כמו ה-inverse של seforim.db: מפרש שקורא את בסיסו רואה אותו כ'מקור'
        // וירטואלי בפאנל הקישורים, לא כמפרש.
        connectionType: LinkTypes.isDependentTextLink(r.connectionType)
            ? LinkTypes.source
            : r.connectionType,
        targetSource: BookSource.fromUserFlag(r.sourceIsUserBook),
        targetCategoryId: r.sourceCategoryId,
      ),
    );
  }

  return _applyCommentatorFilter(dedupeUserLinks(result), targetBookTitles);
}

/// כותרות מפרשי-המשתמש של ספר — להזנת רשימת המפרשים לבחירה (שאחרת נבנית
/// רק מ-seforim.db ואינה מכירה קישורי-משתמש). ריק אם user_books.db לא פתוח.
Future<List<String>> loadUserCommentatorTitles({
  required String bookTitle,
  required int? bookCategoryId,
  required BookSource source,
}) async {
  if (source.isAttached) return const [];
  final repo = UserBooksDatabaseHolder.instance.repositoryIfInitialized;
  if (repo == null) return const [];
  return UserContentRepository(repo.database).userCommentatorTitles(
    bookTitle,
    sourceIsUserBook: source.isUser,
    sourceCategoryId: bookCategoryId,
  );
}

/// מסיר כפילויות בין forward ל-inverse: קישור דו-כיווני (כמו שמייצר "מנהל
/// המפרשים והקישורים") מיובא משני קבצים ומופיע משני הכיוונים — זהו אותו קישור.
/// ה-forward נוסף ראשון ולכן נשמר (ה-heRef שלו עדיף).
/// ⚠️ עוגן שונה אינו כפילות, ורשומה חסרת-עוגן נבלעת במעוגנת — הכלל של
/// `mergeUserLinks` בייבוא.
@visibleForTesting
List<Link> dedupeUserLinks(List<Link> links) {
  // המפתח כולל גם את מקור היעד וקטגוריה — שני ספרים שונים יכולים לחלוק כותרת.
  String keyOf(Link l) =>
      '${l.index1}|${l.path2}|${l.index2}|'
      '${l.connectionType}|${l.targetSource.wireKey}|${l.targetCategoryId}';

  final anchoredKeys = <String>{
    for (final link in links)
      if (link.anchorStart != null) keyOf(link),
  };
  final seen = <String>{};
  return links.where((l) {
    final key = keyOf(l);
    if (l.anchorStart == null) {
      return !anchoredKeys.contains(key) && seen.add(key);
    }
    return seen.add('$key|@${l.anchorStart}');
  }).toList();
}

/// מסנן קישורי-מפרש לפי המפרשים הנבחרים (כמו הסינון ב-getLinksForBookRange):
/// קישור תלוי-טקסט נכלל רק אם כותרת היעד נבחרה; קישורי הפניה תמיד עוברים.
List<Link> _applyCommentatorFilter(
  List<Link> links,
  List<String>? targetBookTitles,
) {
  if (targetBookTitles == null) return links;
  final selected = targetBookTitles.toSet();
  return links.where((link) {
    if (!LinkTypes.isDependentTextLink(link.connectionType)) return true;
    return selected.contains(utils.getTitleFromPath(link.path2));
  }).toList();
}
