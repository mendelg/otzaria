import 'package:flutter/foundation.dart';
import 'package:otzaria/library_update/bloc/library_update_bloc.dart';

/// מתאם פשוט שמונע הרצת עבודות startup כבדות לפני שהוחלט
/// אם האינדוקס האוטומטי ירוץ, ולפני שהוא הסתיים בפועל.
class StartupWorkGate {
  bool _libraryLoaded = false;
  bool _indexingDecisionResolved = false;
  bool _indexingPendingOrRunning = false;
  bool _startupWorkStarted = false;

  /// מסמן שהספרייה נטענה.
  void markLibraryLoaded() {
    _libraryLoaded = true;
  }

  /// מסמן שהוחלט האם האינדוקס האוטומטי אמור לרוץ.
  void markIndexingDecisionResolved({required bool expectIndexing}) {
    _indexingDecisionResolved = true;
    _indexingPendingOrRunning = expectIndexing;
  }

  /// מעדכן את מצב האינדוקס בפועל.
  void markIndexingRunning(bool isRunning) {
    _indexingPendingOrRunning = isRunning;
  }

  /// מחזיר `true` פעם אחת בלבד, ורק כאשר בטוח להתחיל עבודות startup נוספות.
  bool consumeStartPermission() {
    if (_startupWorkStarted ||
        !_libraryLoaded ||
        !_indexingDecisionResolved ||
        _indexingPendingOrRunning) {
      return false;
    }

    _startupWorkStarted = true;
    return true;
  }
}

/// מתחיל את סנכרון הרקע פעם אחת לאחר פתיחת [gate].
bool tryStartDeferredStartupWork({
  required StartupWorkGate gate,
  required VoidCallback startBackgroundSync,
}) {
  if (!gate.consumeStartPermission()) {
    return false;
  }
  startBackgroundSync();
  return true;
}

/// האם עדכון ספרייה שהתחיל הגיע למצב שבו אפשר להמשיך לאינדוקס.
/// דיאלוג ההורדה המלאה חוסם ונפתר מיד; בחירת מסלול באזור ההתראות — לא.
bool libraryUpdateSettledForIndexing(LibraryUpdateState state) =>
    !state.isBusy && state.status != LibraryUpdateStatus.needsFullConfirmation;

/// שלבי העלייה שלפני האינדוקס: סיור ← בדיקת תוכנה ← עדכון ספרייה.
///
/// כשעדכון הספרייה לא אמור לרוץ ([shouldCheckLibraryUpdate]) חוזרים מיד.
/// גרסת תוכנה חדשה מדלגת עליו — היא עשויה לשנות את סכמת הספרייה.
Future<void> runStartupUpdatesBeforeIndexing({
  required bool Function() shouldCheckLibraryUpdate,
  required Future<void> Function() tourFinished,
  required Future<bool> Function() isSoftwareUpdateAvailable,
  required Future<void> Function() runLibraryUpdate,
}) async {
  if (!shouldCheckLibraryUpdate()) return;
  await tourFinished();
  if (await isSoftwareUpdateAvailable()) return;
  await runLibraryUpdate();
}
