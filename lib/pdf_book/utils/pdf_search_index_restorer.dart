/// משחזר את אינדקס ההתאמה שנשמר עם הטאב — פעם אחת, בחיפוש הראשון אחרי הפתיחה.
/// בחיפוש חדש המיקום של השאילתה הקודמת אינו מצביע על ההתאמות החדשות.
class PdfSearchIndexRestorer {
  PdfSearchIndexRestorer(this._pending);

  int? _pending;
  int? _session;

  /// החיפוש נבנה מחדש (טעינה חוזרת של המסמך) — ה-session הבא הוא הראשון.
  void resetSession() => _session = null;

  /// מחזיר את האינדקס שיש לנווט אליו עכשיו, או null.
  int? onSearcherUpdate({
    required int session,
    required bool isSearching,
    required int matchCount,
  }) {
    final pending = _pending;
    if (pending == null) return null;
    _session ??= session;
    if (session != _session || (!isSearching && pending >= matchCount)) {
      _pending = null;
      return null;
    }
    if (pending >= matchCount) return null;
    _pending = null;
    return pending;
  }
}
