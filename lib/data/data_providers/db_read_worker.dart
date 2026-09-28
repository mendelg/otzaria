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

/// ה-worker לא ענה, נפל או לא עלה — הקורא חוזר למסלול הישיר.
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

  /// בקשה שלא נענתה בזמן הזה מסמנת את ה-worker כתקוע; עד שיענה, הבקשות
  /// הולכות למסלול הישיר (חיבור חדש), כמו לפני שה-worker היה קיים.
  @visibleForTesting
  static Duration stallTimeout = const Duration(seconds: 10);

  /// תקרה לפקודות ההשהיה/הסגירה, כמו ב-FindRefDbIsolate.
  static const Duration _lifecycleCommandTimeout = Duration(seconds: 10);

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
    final service = await _instanceOrSpawn();
    if (service._stalled) {
      throw const DbReadWorkerUnavailable('stalled');
    }
    return service
        ._send(method, args)
        .timeout(
          stallTimeout,
          onTimeout: () {
            service._stalled = true;
            debugPrint('[DbReadWorker] "$method" stalled — using direct path');
            throw const DbReadWorkerUnavailable('timeout');
          },
        );
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
      final results =
          await request('batch', {
                'items': [
                  for (final item in items)
                    {'method': item.method, 'args': item.args},
                ],
              })
              as List;
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
    if (service == null || service._disposed) return true;
    return await service._lifecycle('suspend', const {}) == true;
  }

  static Future<void> resumeAfterExternalWrite() async {
    _suspendedForExternalWrite = false;
    final service = _instance;
    if (service == null || service._disposed) return;
    await service._lifecycle('resume', const {});
  }

  /// סוגר את החיבור (הוא ייפתח מחדש בבקשה הבאה). נקרא כשהחיבור הראשי נסגר,
  /// כדי שה-worker לא יחזיק את הקובץ אחרי שה-provider שחרר אותו.
  static Future<void> closeConnectionIfRunning() async {
    final service = _instance;
    if (service == null || service._disposed) return;
    final closing = service._send('close', const {});
    // worker תקוע לא יעכב את היציאה מהתוכנה.
    if (service._stalled) {
      closing.ignore();
      return;
    }
    await service._awaitLifecycle(closing, 'close');
  }

  @visibleForTesting
  static void disposeForTesting() => _instance?._tearDown();

  Future<Object?> _lifecycle(String method, Map<String, Object?> args) =>
      _awaitLifecycle(_send(method, args), method);

  Future<Object?> _awaitLifecycle(
    Future<Object?> request,
    String method,
  ) async {
    try {
      return await request.timeout(_lifecycleCommandTimeout);
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
    if (suspended) throw const _Suspended();
    final current = repository;
    if (current != null && openPath == path) return current;
    closeConnection();
    final repo = SeforimRepository(MyDatabase.withPath(path, readOnly: true));
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
        return closeConnection();
      case 'linkContent':
        final repo = await ensureRepo(args['dbPath'] as String);
        final book = await resolveOfficialBook(
          repo,
          args['title'] as String,
          args['categoryId'] as int?,
        );
        // לא נמצא ברשמי, או ספר קבצים: המסלול הישיר ממשיך למועמד הבא.
        if (book == null) return const {'fallback': true};
        final format = documentFormatOf(
          fileType: book.fileType,
          path: book.filePath,
        );
        if (book.isFileBacked &&
            book.filePath != null &&
            (format?.isTextual ?? false)) {
          return const {'fallback': true};
        }
        return {
          'content': await linkContentFromDbLines(
            repo,
            book.id,
            args['index2'] as int,
            args['index2End'] as int?,
          ),
        };
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
        return {
          'result': [
            for (final item in (args['items'] as List).cast<Map>())
              await runItem(
                item['method'] as String,
                (item['args'] as Map).cast<String, Object?>(),
              ),
          ],
        };
      }
      return {'result': await dispatch(method, args)};
    } on _Suspended {
      return const {'suspended': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // עיבוד סדרתי: פקודת סגירה לא תסגור חיבור באמצע שאילתה בנקודת await.
  final queue = <Map>[];
  var draining = false;

  Future<void> drain() async {
    if (draining) return;
    draining = true;
    try {
      while (queue.isNotEmpty) {
        final message = queue.removeAt(0);
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
    queue.add(message);
    drain();
  });
}
