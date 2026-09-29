import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:otzaria/data/data_providers/book_database_resolver.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart'
    show runRangeRequestOnConnection;
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/db_capabilities.dart';
import 'package:otzaria/migration/database/query_loader.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/migration/models/book.dart' as db_models;
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/utils/file/document_format.dart';

/// חיבור RO פתוח ויכולותיו, כפי שה-worker מעביר לטעינות הטווח.
typedef ReadOnlyConnection = ({
  sqlite3.Database db,
  DbCapabilities capabilities,
});

/// ה-worker לא ענה, נפל או לא עלה — הקורא עובר למסלול חלופי.
class DbReadWorkerUnavailable implements Exception {
  const DbReadWorkerUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'DbReadWorkerUnavailable: $reason';
}

/// ה-worker מושהה לכתיבה חיצונית; אסור לפתוח את seforim.db עד השחרור.
class DbReadWorkerSuspended implements Exception {
  const DbReadWorkerSuspended();

  @override
  String toString() => 'DbReadWorkerSuspended';
}

/// נזרק כשרק ה-worker לא שחרר את הקובץ, כדי שעדכון שכבר הצליח יוכל להמשיך.
class DbReadWorkerNotReleased extends StateError {
  DbReadWorkerNotReleased(super.message);
}

/// תוכן קישור משורות [bookId]: שורה [index2], או כל הטווח עד [index2End]
/// (1-based, כולל). משותף ל-worker ולמסלול הישיר, כדי שהפלט יהיה זהה.
Future<String> linkContentFromDbLines(
  SeforimRepository repository,
  int bookId,
  int index2,
  int? index2End,
) async {
  final line = await repository.getLineByIndex(bookId, index2 - 1);
  if (line == null) return 'שגיאה: אינדקס מחוץ לטווח';

  final end0 = (index2End ?? index2) - 1;
  if (end0 <= index2 - 1) return line.content;
  final rangeLines = await repository.getLines(bookId, index2 - 1, end0);
  if (rangeLines.isEmpty) return line.content;
  return rangeLines.map((l) => l.content).join('<br>');
}

Future<Map<String, Object?>> _officialLinkContent(
  SeforimRepository repository,
  db_models.Book? book,
  Map<String, Object?> args,
) async {
  if (book == null) return const {'fallback': true};
  final format = documentFormatOf(fileType: book.fileType, path: book.filePath);
  if (book.isFileBacked &&
      book.filePath != null &&
      (format?.isTextual ?? false)) {
    return const {'fallback': true};
  }
  return {
    'content': await linkContentFromDbLines(
      repository,
      book.id,
      args['index2'] as int,
      args['index2End'] as int?,
    ),
  };
}

Future<List<Map<String, Object?>>> _readBatchOnFreshConnection(
  List<Map<String, Object?>> items,
  Map<String, Map<String, String>> queryCache,
) async {
  QueryLoader.seedCache(queryCache);
  MyDatabase? database;
  SeforimRepository? repository;
  String? openPath;
  final resolvedBooks = <(String, int?), db_models.Book?>{};
  Future<SeforimRepository> repoFor(String path) async {
    if (repository != null && openPath == path) return repository!;
    database?.close();
    resolvedBooks.clear();
    database = MyDatabase.withPath(path, readOnly: true);
    repository = SeforimRepository(database!);
    await repository!.ensureInitialized();
    openPath = path;
    return repository!;
  }

  try {
    final results = <Map<String, Object?>>[];
    for (final item in items) {
      try {
        final method = item['method'] as String;
        final args = (item['args'] as Map).cast<String, Object?>();
        final repo = await repoFor(args['dbPath'] as String);
        if (method == 'breadcrumb') {
          results.add({
            'result': await repo.getLineBreadcrumb(
              args['bookId'] as int,
              args['lineIndex'] as int,
            ),
          });
          continue;
        }
        if (method != 'linkContent') {
          throw StateError('Unknown DbReadWorker method: $method');
        }
        final key = (args['title'] as String, args['categoryId'] as int?);
        if (!resolvedBooks.containsKey(key)) {
          final resolved = await BookDatabaseResolver.resolveBookInCandidates(
            title: key.$1,
            candidates: [
              ResolvedBookRepositoryCandidate(
                repository: repo,
                source: BookSource.official,
              ),
            ],
            categoryId: key.$2,
          );
          resolvedBooks[key] = resolved?.book;
        }
        results.add({
          'result': await _officialLinkContent(repo, resolvedBooks[key], args),
        });
      } catch (error) {
        results.add({'error': error.toString()});
      }
    }
    return results;
  } finally {
    database?.close();
  }
}

/// isolate קבוע שקורא את seforim.db בשביל מסלולי הקריאה החמים (טווחי טקסט
/// וקישורים, תוכן מפרשים, נתיבי כותרות), על חיבור RO אחד שנפתח פעם אחת.
///
/// נפרד מ-FindRefDbIsolate: חימום ה-AltToc שם אורך שניות, ופתיחת ספר לא
/// תמתין מאחוריו. נוצר בעצלתיים בבקשה הראשונה, לעולם לא בעלייה.
class DbReadWorker {
  DbReadWorker._();

  static DbReadWorker? _instance;
  static Future<DbReadWorker>? _spawnFuture;
  static bool _suspendedForExternalWrite = false;
  static bool _closedUntilReopen = false;
  static final Set<Future<void>> _oneShotReads = {};

  /// בקשה שלא נענתה בזמן הזה מסמנת את ה-worker כתקוע; עד שיענה, הבקשות
  /// עוברות למסלול חלופי מחוץ ל-UI isolate.
  @visibleForTesting
  static Duration stallTimeout = const Duration(seconds: 10);

  // קצר בכוונה: פקודת בקרה ממתינה רק לבקשה שכבר בביצוע, וכל המתנה
  // מעכבת את עדכון הספרייה ואת הסגירה.
  @visibleForTesting
  static Duration lifecycleCommandTimeout = const Duration(seconds: 4);

  static Future<DbReadWorker> _instanceOrSpawn() {
    final existing = _instance;
    if (existing != null && !existing._disposed) return Future.value(existing);
    return _spawnFuture ??= _spawn().then(
      (service) {
        _instance = service;
        _spawnFuture = null;
        // נשלח לפני כל בקשה שממתינה ל-spawn, כדי שלא ייפתח חיבור בחלון הכתיבה.
        if (_suspendedForExternalWrite) {
          service._send('suspend', const {}).ignore();
        }
        return service;
      },
      onError: (Object error, StackTrace st) {
        _spawnFuture = null;
        throw DbReadWorkerUnavailable('spawn failed: $error');
      },
    );
  }

  static Future<DbReadWorker> _spawn() async {
    await QueryLoader.initialize();
    final service = DbReadWorker._();
    service._messagesSub = service._receivePort.listen(service._handleMessage);
    service._errorSub = service._errorPort.listen(service._handleWorkerError);
    service._exitSub = service._exitPort.listen(service._handleWorkerExit);
    try {
      service._isolate = await Isolate.spawn<_Bootstrap>(
        _workerMain,
        _Bootstrap(
          mainSendPort: service._receivePort.sendPort,
          queryCache: QueryLoader.cacheSnapshot,
        ),
        debugName: 'db_read_worker',
        onError: service._errorPort.sendPort,
        onExit: service._exitPort.sendPort,
      );
      await service._readyCompleter.future;
    } catch (_) {
      service._tearDown();
      rethrow;
    }
    return service;
  }

  final ReceivePort _receivePort = ReceivePort();
  final ReceivePort _errorPort = ReceivePort();
  final ReceivePort _exitPort = ReceivePort();
  late final StreamSubscription<dynamic> _messagesSub;
  late final StreamSubscription<dynamic> _errorSub;
  late final StreamSubscription<dynamic> _exitSub;
  final Completer<void> _readyCompleter = Completer<void>();
  final Map<int, Completer<Object?>> _pending = {};
  Isolate? _isolate;
  SendPort? _commandPort;
  int _nextId = 0;
  bool _disposed = false;
  bool _stalled = false;

  /// שולח בקשה ל-worker. זורק [DbReadWorkerUnavailable] כשה-worker אינו
  /// זמין או תקוע, ו-[DbReadWorkerSuspended] בזמן כתיבה חיצונית.
  static Future<Object?> request(
    String method,
    Map<String, Object?> args,
  ) async {
    // קודם ההשהיה: worker תקוע היה שולח את הקורא לפתוח את הקובץ באמצע כתיבה.
    if (_suspendedForExternalWrite || _closedUntilReopen) {
      throw const DbReadWorkerSuspended();
    }
    final service = await _instanceOrSpawn();
    // השהיה/סגירה שהגיעה בזמן ה-spawn: אסור לשלוח, אחרת ה-worker יפתח את הקובץ.
    if (_suspendedForExternalWrite || _closedUntilReopen) {
      throw const DbReadWorkerSuspended();
    }
    if (service._stalled) {
      throw const DbReadWorkerUnavailable('stalled');
    }
    return service
        ._send(method, args)
        .timeout(
          stallTimeout,
          onTimeout: () {
            service._stalled = true;
            debugPrint('[DbReadWorker] "$method" stalled — using fallback');
            throw const DbReadWorkerUnavailable('timeout');
          },
        );
  }

  /// אצוות התאוששות על חיבור זמני מחוץ ל-UI isolate.
  static Future<List<Map<String, Object?>>> _batchOnFreshIsolate(
    List<Map<String, Object?>> items,
  ) async {
    if (_suspendedForExternalWrite || _closedUntilReopen) {
      throw const DbReadWorkerSuspended();
    }
    await QueryLoader.initialize();
    if (_suspendedForExternalWrite || _closedUntilReopen) {
      throw const DbReadWorkerSuspended();
    }
    final queryCache = QueryLoader.cacheSnapshot;
    final read = Isolate.run(
      () => _readBatchOnFreshConnection(items, queryCache),
    );
    final tracked = read.then<void>((_) {}, onError: (Object _) {});
    _oneShotReads.add(tracked);
    try {
      return await read;
    } finally {
      _oneShotReads.remove(tracked);
    }
  }

  static Future<bool> _waitForOneShotReads() async {
    try {
      await Future.wait(_oneShotReads).timeout(lifecycleCommandTimeout);
      return true;
    } on TimeoutException {
      debugPrint('[DbReadWorker] fallback reads did not release DB in time');
      return false;
    }
  }

  static final List<_BatchItem> _batch = [];

  /// כמו [request], אבל בקשות שנשלחות באותו סבב סינכרוני (למשל כל המפרשים
  /// שנבנו באותו פריים) יוצאות ל-worker כבקשה אחת.
  static Future<Object?> batched(String method, Map<String, Object?> args) {
    final item = _BatchItem(method, args);
    _batch.add(item);
    if (_batch.length == 1) scheduleMicrotask(_flushBatch);
    return item.completer.future;
  }

  static Future<void> _flushBatch() async {
    final items = List.of(_batch);
    _batch.clear();
    try {
      final requests = [
        for (final item in items) {'method': item.method, 'args': item.args},
      ];
      List results;
      try {
        results = await request('batch', {'items': requests}) as List;
        if (results.any(
          (result) => result is Map && result.containsKey('error'),
        )) {
          results = await _batchOnFreshIsolate(requests);
        }
      } on DbReadWorkerUnavailable {
        results = await _batchOnFreshIsolate(requests);
      }
      for (var i = 0; i < items.length; i++) {
        final result = results[i] as Map;
        final completer = items[i].completer;
        if (result['suspended'] == true) {
          completer.completeError(const DbReadWorkerSuspended());
        } else if (result.containsKey('error')) {
          completer.completeError(StateError(result['error'].toString()));
        } else {
          completer.complete(result['result']);
        }
      }
    } catch (error) {
      for (final item in items) {
        if (!item.completer.isCompleted) item.completer.completeError(error);
      }
    }
  }

  /// משחרר את חיבור ה-RO לפני כתיבה חיצונית ומונע פתיחה עד
  /// [resumeAfterExternalWrite]. `false` — השחרור לא אומת.
  static Future<bool> suspendForExternalWrite() async {
    _suspendedForExternalWrite = true;
    final service = _instance;
    final released = service == null || service._disposed
        ? true
        : await service._lifecycle('suspend', const {}) == true;
    return released && await _waitForOneShotReads();
  }

  static Future<void> resumeAfterExternalWrite() async {
    _suspendedForExternalWrite = false;
    final service = _instance;
    if (service == null || service._disposed) return;
    await service._lifecycle('resume', const {});
  }

  /// סוגר את החיבור עד [allowReopen]. נקרא כשהחיבור הראשי נסגר,
  /// כדי שה-worker לא יחזיק את הקובץ אחרי שה-provider שחרר אותו.
  /// [wait] כבוי ביציאה מהתוכנה: סיום התהליך משחרר את הקובץ ממילא.
  static Future<void> closeConnectionIfRunning({bool wait = true}) async {
    _closedUntilReopen = true;
    final service = _instance;
    if (service != null && !service._disposed) {
      final closing = service._send('close', const {});
      if (!wait || service._stalled) {
        closing.ignore();
      } else {
        await service._awaitLifecycle(closing, 'close');
      }
    }
    if (wait) await _waitForOneShotReads();
  }

  /// שוכח את הספרים שנפתרו — נקרא מיד אחרי commit של עדכון, כדי שבקשה
  /// שלפני הסגירה לא תקבל מזהה ספר ישן.
  /// מתיר שוב פתיחת חיבור אחרי [closeConnectionIfRunning]; נקרא רק אחרי אתחול
  /// מוצלח של ה-provider, כדי שקורא מקביל לא יפתח קובץ שמוחלף.
  static void allowReopen() {
    _closedUntilReopen = false;
    final service = _instance;
    if (service == null || service._disposed) return;
    service._send('open', const {}).ignore();
  }

  static void clearBookCacheIfRunning() {
    final service = _instance;
    if (service == null || service._disposed) return;
    service._send('clearBookCache', const {}).ignore();
  }

  @visibleForTesting
  static void disposeForTesting() {
    _closedUntilReopen = false;
    _instance?._tearDown();
  }

  Future<Object?> _lifecycle(String method, Map<String, Object?> args) =>
      _awaitLifecycle(_send(method, args), method);

  Future<Object?> _awaitLifecycle(
    Future<Object?> request,
    String method,
  ) async {
    try {
      return await request.timeout(lifecycleCommandTimeout);
    } on TimeoutException {
      request.ignore();
      debugPrint('[DbReadWorker] $method timed out — DB handle may be open');
    } catch (e) {
      debugPrint('[DbReadWorker] $method failed: $e');
    }
    return null;
  }

  /// מספר ההודעות שנשלחו ל-worker — לבדיקת איגוד הבקשות.
  @visibleForTesting
  static int sentMessageCount = 0;

  Future<Object?> _send(String method, Map<String, Object?> args) async {
    if (_disposed) throw const DbReadWorkerUnavailable('disposed');
    if (!_readyCompleter.isCompleted) await _readyCompleter.future;
    sentMessageCount++;
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _commandPort!.send({'id': id, 'method': method, 'args': args});
    return completer.future;
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      _commandPort = message;
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      return;
    }
    if (message is! Map) return;
    _stalled = false;
    final completer = _pending.remove(message['id']);
    if (completer == null || completer.isCompleted) return;
    if (message['suspended'] == true) {
      completer.completeError(const DbReadWorkerSuspended());
    } else if (message.containsKey('error')) {
      completer.completeError(StateError(message['error'].toString()));
    } else {
      completer.complete(message['result']);
    }
  }

  void _handleWorkerError(dynamic message) {
    _failAllPending(DbReadWorkerUnavailable('worker error: $message'));
    _tearDown();
  }

  void _handleWorkerExit(dynamic _) {
    if (_disposed) return;
    _failAllPending(const DbReadWorkerUnavailable('worker exited'));
    _tearDown();
  }

  void _failAllPending(Object error) {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.future.ignore();
      _readyCompleter.completeError(error);
    }
    final pending = List.of(_pending.values);
    _pending.clear();
    for (final c in pending) {
      if (!c.isCompleted) c.completeError(error);
    }
  }

  void _tearDown() {
    if (_disposed) return;
    _disposed = true;
    _failAllPending(const DbReadWorkerUnavailable('disposed'));
    _messagesSub.cancel();
    _errorSub.cancel();
    _exitSub.cancel();
    _receivePort.close();
    _errorPort.close();
    _exitPort.close();
    _isolate?.kill(priority: Isolate.immediate);
    if (identical(_instance, this)) _instance = null;
  }
}

class _BatchItem {
  _BatchItem(this.method, this.args);

  final String method;
  final Map<String, Object?> args;
  final Completer<Object?> completer = Completer<Object?>();
}

class _Bootstrap {
  const _Bootstrap({required this.mainSendPort, required this.queryCache});

  final SendPort mainSendPort;
  final Map<String, Map<String, String>> queryCache;
}

class _Suspended implements Exception {
  const _Suspended();
}

/// ספרים שנפתרו כבר על החיבור הנוכחי; מתנקה בכל סגירה.
const _maxResolvedBooks = 4096;

void _workerMain(_Bootstrap bootstrap) {
  QueryLoader.seedCache(bootstrap.queryCache);
  final receivePort = ReceivePort();
  bootstrap.mainSendPort.send(receivePort.sendPort);

  String? openPath;
  SeforimRepository? repository;
  var suspended = false;
  var closed = false;
  final resolvedBooks = <String, db_models.Book?>{};

  bool closeConnection() {
    final closing = repository;
    repository = null;
    openPath = null;
    resolvedBooks.clear();
    try {
      closing?.database.close();
      return true;
    } catch (e) {
      debugPrint('[DbReadWorker] close failed: $e');
      return false;
    }
  }

  Future<SeforimRepository> ensureRepo(String path) async {
    if (suspended || closed) throw const _Suspended();
    final current = repository;
    if (current != null && openPath == path) return current;
    closeConnection();
    final repo = SeforimRepository(
      MyDatabase.withPath(path, readOnly: true, official: true),
    );
    try {
      await repo.ensureInitialized();
    } catch (_) {
      repo.database.close();
      rethrow;
    }
    repository = repo;
    openPath = path;
    return repo;
  }

  Future<db_models.Book?> resolveOfficialBook(
    SeforimRepository repo,
    String title,
    int? categoryId,
  ) async {
    final key = '$title\u0000${categoryId ?? ''}';
    if (resolvedBooks.containsKey(key)) return resolvedBooks[key];
    final resolved = await BookDatabaseResolver.resolveBookInCandidates(
      title: title,
      candidates: [
        ResolvedBookRepositoryCandidate(
          repository: repo,
          source: BookSource.official,
        ),
      ],
      categoryId: categoryId,
    );
    if (resolvedBooks.length >= _maxResolvedBooks) resolvedBooks.clear();
    return resolvedBooks[key] = resolved?.book;
  }

  Future<Object?> dispatch(String method, Map<String, Object?> args) async {
    switch (method) {
      case 'suspend':
        suspended = true;
        return closeConnection();
      case 'resume':
        suspended = false;
        return null;
      case 'close':
        closed = true;
        return closeConnection();
      case 'open':
        closed = false;
        return null;
      case 'clearBookCache':
        resolvedBooks.clear();
        return null;
      case 'linkContent':
        final repo = await ensureRepo(args['dbPath'] as String);
        final book = await resolveOfficialBook(
          repo,
          args['title'] as String,
          args['categoryId'] as int?,
        );
        return _officialLinkContent(repo, book, args);
      case 'breadcrumb':
        final repo = await ensureRepo(args['dbPath'] as String);
        return repo.getLineBreadcrumb(
          args['bookId'] as int,
          args['lineIndex'] as int,
        );
      default:
        final repo = await ensureRepo(args['dbPath'] as String);
        final connection = (
          db: await repo.database.database,
          capabilities: await repo.database.capabilities,
        );
        return runRangeRequestOnConnection(method, args, connection);
    }
  }

  Future<Map<String, Object?>> runItem(
    String method,
    Map<String, Object?> args,
  ) async {
    try {
      if (method == 'batch') {
        final results = <Map<String, Object?>>[];
        for (final item in (args['items'] as List).cast<Map>()) {
          // השאילתות סינכרוניות: בלי ויתור על תור האירועים suspend/close שהגיע
          // לא ייקלט עד סוף ה-batch.
          if (results.isNotEmpty) await Future<void>.delayed(Duration.zero);
          results.add(
            await runItem(
              item['method'] as String,
              (item['args'] as Map).cast<String, Object?>(),
            ),
          );
        }
        return {'result': results};
      }
      return {'result': await dispatch(method, args)};
    } on _Suspended {
      return const {'suspended': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // עיבוד סדרתי: פקודת סגירה לא תסגור חיבור באמצע שאילתה בנקודת await.
  final controls = <Map>[];
  final queue = <Map>[];
  var draining = false;

  Future<void> drain() async {
    if (draining) return;
    draining = true;
    try {
      while (controls.isNotEmpty || queue.isNotEmpty) {
        // מחזור באירועים: פקודת בקרה שכבר הגיעה נקלטת לפני הבקשה הבאה.
        await Future<void>.delayed(Duration.zero);
        if (controls.isEmpty && queue.isEmpty) break;
        final message = controls.isNotEmpty
            ? controls.removeAt(0)
            : queue.removeAt(0);
        final reply = await runItem(
          message['method'] as String,
          (message['args'] as Map).cast<String, Object?>(),
        );
        bootstrap.mainSendPort.send({'id': message['id'], ...reply});
      }
    } finally {
      draining = false;
    }
  }

  receivePort.listen((dynamic message) {
    if (message is! Map) return;
    final method = message['method'];
    if (const {
      'suspend',
      'resume',
      'close',
      'open',
      'clearBookCache',
    }.contains(method)) {
      if (method == 'suspend' || method == 'close') {
        // הדגל נקבע כבר כאן, כדי שגם פריטי batch שרץ כעת לא יתחילו שאילתה חדשה
        // ולא יפתחו מחדש את החיבור לפני שהפקודה עצמה מבוצעת.
        if (method == 'suspend') suspended = true;
        if (method == 'close') closed = true;
        for (final queued in queue) {
          bootstrap.mainSendPort.send({'id': queued['id'], 'suspended': true});
        }
        queue.clear();
      }
      controls.add(message);
    } else {
      queue.add(message);
    }
    drain();
  });
}
