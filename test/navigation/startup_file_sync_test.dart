import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library_update/bloc/library_update_bloc.dart';
import 'package:otzaria/navigation/view/startup_work_gate.dart';

void main() {
  group('tryStartDeferredStartupWork', () {
    late int backgroundSyncCalls;

    setUp(() => backgroundSyncCalls = 0);

    bool tryStart(StartupWorkGate gate) => tryStartDeferredStartupWork(
      gate: gate,
      startBackgroundSync: () => backgroundSyncCalls++,
    );

    test('מתחיל סנכרון רקע פעם אחת כשהשער נפתח', () {
      final gate = StartupWorkGate();
      gate.markLibraryLoaded();
      gate.markIndexingDecisionResolved(expectIndexing: false);

      expect(tryStart(gate), isTrue);
      expect(tryStart(gate), isFalse);
      expect(backgroundSyncCalls, 1);
    });

    test('לא מתחיל עבודות לפני שהשער נפתח', () {
      expect(tryStart(StartupWorkGate()), isFalse);
      expect(backgroundSyncCalls, 0);
    });
  });

  group('runStartupUpdatesBeforeIndexing', () {
    late List<String> steps;

    setUp(() => steps = []);

    Future<void> run({
      bool shouldCheck = true,
      Future<void> Function()? tourFinished,
      Future<bool> Function()? softwareUpdateAvailable,
    }) => runStartupUpdatesBeforeIndexing(
      shouldCheckLibraryUpdate: () {
        steps.add('shouldCheck');
        return shouldCheck;
      },
      tourFinished: () async {
        steps.add('tour');
        await tourFinished?.call();
      },
      isSoftwareUpdateAvailable: () {
        steps.add('software');
        return softwareUpdateAvailable?.call() ?? Future.value(false);
      },
      runLibraryUpdate: () async => steps.add('library'),
    );

    test('סיור ← תוכנה ← ספרייה', () async {
      await run();
      expect(steps, ['shouldCheck', 'tour', 'software', 'library']);
    });

    test('עדכונים כבויים: חוזר מיד, בלי סיור ובלי בדיקת תוכנה', () async {
      await run(shouldCheck: false);
      expect(steps, ['shouldCheck']);
    });

    test('לא מעדכן ספרייה כשזמינה גרסת תוכנה חדשה', () async {
      await run(softwareUpdateAvailable: () => Future.value(true));
      expect(steps, ['shouldCheck', 'tour', 'software']);
    });

    test('ממתין לסוף הסיור לפני בדיקת התוכנה', () async {
      final tour = Completer<void>();
      final done = run(tourFinished: () => tour.future);
      await pumpEventQueue();
      expect(steps, ['shouldCheck', 'tour']);

      tour.complete();
      await done;
      expect(steps.last, 'library');
    });

    test('עדכון הספרייה ממתין לתשובת בדיקת התוכנה', () async {
      final software = Completer<bool>();
      final done = run(softwareUpdateAvailable: () => software.future);
      await pumpEventQueue();
      expect(steps, isNot(contains('library')));

      software.complete(false);
      await done;
      expect(steps.last, 'library');
    });
  });

  group('libraryUpdateSettledForIndexing', () {
    bool settled(LibraryUpdateStatus status) =>
        libraryUpdateSettledForIndexing(LibraryUpdateState(status: status));

    test('ממתין בזמן עבודה ובדיאלוג ההורדה המלאה החוסם', () {
      for (final status in [
        LibraryUpdateStatus.checking,
        LibraryUpdateStatus.downloading,
        LibraryUpdateStatus.applying,
        LibraryUpdateStatus.refreshing,
        LibraryUpdateStatus.needsFullConfirmation,
      ]) {
        expect(settled(status), isFalse, reason: status.name);
      }
    });

    test('ממשיך בסיום, בכשל, ובבחירת מסלול שאינה חוסמת', () {
      for (final status in [
        LibraryUpdateStatus.idle,
        LibraryUpdateStatus.completed,
        LibraryUpdateStatus.error,
        LibraryUpdateStatus.disconnected,
        LibraryUpdateStatus.blocked,
        LibraryUpdateStatus.needsRouteChoice,
      ]) {
        expect(settled(status), isTrue, reason: status.name);
      }
    });
  });
}
