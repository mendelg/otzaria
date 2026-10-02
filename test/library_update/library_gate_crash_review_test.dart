import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/windowing/library_suspension_marker.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
import 'package:otzaria/library_update/services/library_access_gate.dart';
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:seforim_library_updater/seforim_library_updater.dart';

/// מתאם שמת באמצע החלפת המסד, עם isolates אמיתיים באותו תהליך.
const String _namespace = 'otzaria.test.librarygate.crash';

LibraryAccessGate _gate() => LibraryAccessGate(
  ackTimeout: const Duration(seconds: 3),
  resumeTimeout: const Duration(seconds: 3),
  leaseCheckInterval: const Duration(milliseconds: 50),
  selfAccess: LibraryAccessRoutine(
    suspend: () async {},
    resume: (_) async {},
  ),
  logError: (_, _, _) {},
);

/// חלון רגיל: נרשם באפיק ומחזיק "מסד" שנסגר ב-suspend.
Future<void> _peerMain(SendPort ready) async {
  WindowBus.namespace = _namespace;
  var open = true;
  final gate = LibraryAccessGate(
    leaseCheckInterval: const Duration(milliseconds: 50),
    logError: (_, _, _) {},
    peerAccess: LibraryAccessRoutine(
      suspend: () async => open = false,
      resume: (_) async => open = true,
    ),
  );
  final slot = gate.registerWindow();
  WindowBus.instance.onRequest = (request) async {
    if (request['type'] == 'status') return {'open': open};
    return gate.handlePeerRequest(request);
  };
  ready.send(slot);
}

/// המתאם: משעה את כולם ונשאר באמצע ההחלפה עד שהוא נהרג או מתבקש לסיים.
Future<void> _coordinatorMain(List<Object> args) async {
  WindowBus.namespace = _namespace;
  final events = args[0] as SendPort;
  final blockFor = args[1] as int;
  final gate = _gate();
  gate.registerWindow(asOwner: true);
  final suspension = await gate.suspendAll();
  events.send('suspended');
  if (blockFor > 0) {
    // קריאה נייטיב חוסמת: ה-isolate אינו עונה אפילו ל-ping מיידי.
    sleep(Duration(milliseconds: blockFor));
    await gate.resumeAll(suspension, dbReplaced: false);
    events.send('resumed');
    return;
  }
  await Completer<void>().future;
}

Future<void> _waiterMain(SendPort done) async {
  WindowBus.namespace = _namespace;
  await LibrarySuspensionMarker.waitUntilReleased(
    poll: const Duration(milliseconds: 50),
    cap: const Duration(milliseconds: 100),
  );
  done.send(true);
}

Future<void> _replacementCoordinatorMain(List<Object> args) async {
  WindowBus.namespace = _namespace;
  final events = args[0] as SendPort;
  final dbPath = args[1] as String;
  final gate = _gate();
  gate.registerWindow(asOwner: true);
  await gate.runExclusive(
    dbPath: dbPath,
    body: (scope) async {
      await const LibraryDbRecoveryService().beginApply(
        dbPath: dbPath,
        fromVersion: 1,
        toVersion: 2,
        timestamp: 'test',
      );
      events.send('backup-moved');
      await Completer<void>().future;
      File('$dbPath.new').renameSync(dbPath);
      scope.markDbReplaced();
      const LibraryDbRecoveryService().finishSuccess(dbPath);
    },
  );
}

Future<void> _sqlitePeerMain(List<Object> args) async {
  WindowBus.namespace = _namespace;
  final dbPath = args[0] as String;
  final ready = args[1] as SendPort;
  sqlite3.Database? db = sqlite3.sqlite3.open(
    dbPath,
    mode: sqlite3.OpenMode.readOnly,
  );
  var resumedAfterRecovery = false;
  final gate = LibraryAccessGate(
    leaseCheckInterval: const Duration(milliseconds: 50),
    logError: (_, _, _) {},
    peerAccess: LibraryAccessRoutine(
      suspend: () async {
        db?.close();
        db = null;
      },
      resume: (_) async {
        resumedAfterRecovery =
            !LibrarySuspensionMarker.isRegistered &&
            File(dbPath).existsSync() &&
            !File('$dbPath.backup').existsSync();
        db = sqlite3.sqlite3.open(dbPath, mode: sqlite3.OpenMode.readOnly);
      },
    ),
  );
  final slot = gate.registerWindow();
  WindowBus.instance.onRequest = (request) async {
    if (request['type'] == 'status') {
      return {
        'open': db != null,
        'value': db?.select('SELECT v FROM t').first['v'],
        'recovered': resumedAfterRecovery,
      };
    }
    return gate.handlePeerRequest(request);
  };
  ready.send(slot);
}

Future<void> _sqliteWaiterMain(List<Object> args) async {
  WindowBus.namespace = _namespace;
  await LibrarySuspensionMarker.waitUntilReleased(
    poll: const Duration(milliseconds: 50),
    cap: const Duration(milliseconds: 100),
  );
  final db = sqlite3.sqlite3.open(
    args[0] as String,
    mode: sqlite3.OpenMode.readOnly,
  );
  try {
    (args[1] as SendPort).send(db.select('SELECT v FROM t').first['v']);
  } finally {
    db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final isolates = <Isolate>[];

  setUp(() => WindowBus.namespace = _namespace);

  tearDown(() async {
    for (final isolate in isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    isolates.clear();
    LibrarySuspensionMarker.resetForTesting();
    for (var i = 1; i <= WindowBus.slotCount; i++) {
      IsolateNameServer.removePortNameMapping('$_namespace.$i');
    }
    IsolateNameServer.removePortNameMapping('$_namespace.owner');
    WindowBus.instance.unregister();
    WindowBus.namespace = 'otzaria.window';
  });

  Future<int> spawnPeer() async {
    final ready = ReceivePort();
    isolates.add(await Isolate.spawn(_peerMain, ready.sendPort));
    return await ready.first as int;
  }

  Future<bool?> isOpen(int slot) async {
    final status = await WindowBus.instance.request(slot, const {
      'type': 'status',
    });
    return status is Map ? status['open'] as bool? : null;
  }

  Future<void> eventually(
    Future<bool> Function() condition, {
    Duration within = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(within);
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('condition not reached within ${within.inMilliseconds}ms');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<(Isolate, Stream<Object?>)> spawnCoordinator({
    int blockFor = 0,
  }) async {
    final events = ReceivePort();
    final stream = events.asBroadcastStream();
    final isolate = await Isolate.spawn(_coordinatorMain, [
      events.sendPort,
      blockFor,
    ]);
    isolates.add(isolate);
    return (isolate, stream);
  }

  test('מתאם שנהרג באמצע: החלון חוזר, ממתין משתחרר, ומתאם חדש נועל', () async {
    final peer = await spawnPeer();
    final (coordinator, events) = await spawnCoordinator();
    await events.first.timeout(const Duration(seconds: 5));
    expect(await isOpen(peer), isFalse);
    expect(LibrarySuspensionMarker.isRegistered, isTrue);

    final waiterDone = ReceivePort();
    final waiterFinished = waiterDone.first;
    isolates.add(await Isolate.spawn(_waiterMain, waiterDone.sendPort));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final exited = ReceivePort();
    coordinator.addOnExitListener(exited.sendPort);
    coordinator.kill(priority: Isolate.immediate);
    await exited.first.timeout(const Duration(seconds: 5));
    exited.close();

    await eventually(() async => await isOpen(peer) == true);
    await eventually(() async => !LibrarySuspensionMarker.isRegistered);
    await waiterFinished.timeout(const Duration(seconds: 5));
    waiterDone.close();

    final next = _gate();
    final suspension = await next.suspendAll();
    expect(suspension.releasedSlots, {peer});
    expect(await isOpen(peer), isFalse);
    await next.resumeAll(suspension, dbReplaced: false);
    expect(await isOpen(peer), isTrue);
  });

  test('בלי חלונות מושעים, הממתין לבדו מנקה את הנעילה היתומה', () async {
    final (coordinator, events) = await spawnCoordinator();
    await events.first.timeout(const Duration(seconds: 5));

    final waiterDone = ReceivePort();
    final waiterFinished = waiterDone.first;
    isolates.add(await Isolate.spawn(_waiterMain, waiterDone.sendPort));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(LibrarySuspensionMarker.isRegistered, isTrue);

    coordinator.kill(priority: Isolate.immediate);
    await waiterFinished.timeout(const Duration(seconds: 5));
    waiterDone.close();
    expect(LibrarySuspensionMarker.isRegistered, isFalse);
  });

  test('מתאם חי שחסום בקריאה נייטיב אינו נחשב מת', () async {
    final peer = await spawnPeer();
    final (_, events) = await spawnCoordinator(blockFor: 1500);
    final resumed = events.where((e) => e == 'resumed').first;
    await events.first.timeout(const Duration(seconds: 5));

    // לאורך כל החסימה, פי 30 ממרווח בדיקת השכירות, הנעילה נשמרת.
    final until = DateTime.now().add(const Duration(milliseconds: 1200));
    while (DateTime.now().isBefore(until)) {
      expect(LibrarySuspensionMarker.isRegistered, isTrue);
      expect(await isOpen(peer), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    await resumed.timeout(const Duration(seconds: 5));
    expect(LibrarySuspensionMarker.isRegistered, isFalse);
    await eventually(() async => await isOpen(peer) == true);
  });
  for (final withPeers in [true, false]) {
    test(
      'מות מתאם אחרי הזזה לגיבוי: שחזור לפני חידוש ${withPeers ? "שני עמיתים וממתין" : "ממתין יחיד"}',
      () async {
        final dir = Directory.systemTemp.createTempSync('owner_exit_recovery_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final dbPath = '${dir.path}/seforim.db';
        void writeDb(String path, int value) {
          final db = sqlite3.sqlite3.open(path);
          try {
            db.execute('CREATE TABLE t(v INTEGER)');
            db.execute('INSERT INTO t VALUES (?)', [value]);
          } finally {
            db.close();
          }
        }

        writeDb(dbPath, 1);
        writeDb('$dbPath.new', 2);
        final peers = <int>[];
        if (withPeers) {
          for (var i = 0; i < 2; i++) {
            final ready = ReceivePort();
            isolates.add(
              await Isolate.spawn(_sqlitePeerMain, [dbPath, ready.sendPort]),
            );
            peers.add(await ready.first as int);
            ready.close();
          }
        }
        final checkpoint = ReceivePort();
        final coordinator = await Isolate.spawn(_replacementCoordinatorMain, [
          checkpoint.sendPort,
          dbPath,
        ]);
        isolates.add(coordinator);
        await checkpoint.first.timeout(const Duration(seconds: 5));
        checkpoint.close();
        expect(File(dbPath).existsSync(), isFalse);
        expect(File('$dbPath.backup').existsSync(), isTrue);
        final waiterDone = ReceivePort();
        final finished = waiterDone.first;
        isolates.add(
          await Isolate.spawn(_sqliteWaiterMain, [dbPath, waiterDone.sendPort]),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        coordinator.kill(priority: Isolate.immediate);
        expect(await finished.timeout(const Duration(seconds: 5)), 1);
        waiterDone.close();
        for (final slot in peers) {
          await eventually(() async {
            final status = await WindowBus.instance.request(slot, const {
              'type': 'status',
            });
            return status is Map &&
                status['open'] == true &&
                status['value'] == 1 &&
                status['recovered'] == true;
          });
        }
        expect(File('$dbPath.backup').existsSync(), isFalse);
        expect(File('$dbPath.applying').existsSync(), isFalse);
        expect(LibrarySuspensionMarker.isRegistered, isFalse);
        expect(WindowBus.instance.ownerPort, isNull);
        final next = _gate();
        final suspension = await next.suspendAll();
        expect(suspension.releasedSlots, peers.toSet());
        await next.resumeAll(suspension, dbReplaced: false);
      },
    );
  }

  test('הודעת יציאה ישנה אינה מוחקת חלון מחליף או נעילה חדשה', () async {
    final bus = WindowBus.instance;
    final slot = bus.register(asOwner: true)!;
    final oldPort = bus.portOf(slot)!;
    bus.unregister();
    expect(bus.register(asOwner: true), slot);
    final newPort = bus.portOf(slot)!;
    final gate = _gate();
    final suspension = await gate.suspendAll();
    try {
      await LibrarySuspensionMarker.recoverExitedOwner({
        'operationId': 'already-finished',
        'ownerSlot': slot,
        'ownerPort': oldPort,
      });
      expect(bus.portOf(slot), newPort);
      expect(bus.ownerPort, newPort);
      expect(LibrarySuspensionMarker.isRegistered, isTrue);
    } finally {
      await gate.resumeAll(suspension, dbReplaced: false);
    }
  });

  test('התאוששות שאינה מחזירה מסד שומרת את הקוראים חסומים', () async {
    final dir = Directory.systemTemp.createTempSync('failed_owner_recovery_');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(await LibrarySuspensionMarker.acquire('failed-recovery'), isTrue);
    await expectLater(
      LibrarySuspensionMarker.recoverExitedOwner({
        'operationId': 'failed-recovery',
        'dbPath': '${dir.path}/missing.db',
      }),
      throwsStateError,
    );
    expect(LibrarySuspensionMarker.isRegistered, isTrue);
  });
}
