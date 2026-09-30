import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/attached_libraries/repository/attached_library_registry.dart';
import 'package:otzaria/find_ref/repository/attached_find_ref_worker.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/query_loader.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/models/book_source.dart';

import '../helpers/seforim_fixture_db.dart';

Future<int> _bookCount(SeforimRepository repository) async {
  final db = await repository.database.database;
  return db.select('SELECT COUNT(*) FROM book').first.columnAt(0) as int;
}

AttachedDbJob<int> _hang(SendPort started) => (repository) {
  started.send(null);
  return Completer<int>().future;
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final realDb = Platform.environment['OTZARIA_BENCH_DB'];
  for (final useRealDb in [false, true]) {
    test(
      'timeout רקע שומר אינדקס ומאפשר חיפוש במסדים: real=$useRealDb',
      () async {
        await QueryLoader.initialize();
        final worker = AttachedFindRefWorker.instance;
        worker.reset();
        final previousTimeout = AttachedFindRefWorker.callTimeout;
        final previousRegistry = AttachedLibraryRegistry.instance;
        final registry = AttachedLibraryRegistry(idleTimeout: null)..update([]);
        AttachedLibraryRegistry.instance = registry;
        final dir = await Directory.systemTemp.createTemp(
          'attached_background',
        );
        final other = SeforimFixtureDb.create(dir, SeforimFixtureVariant.full);
        final path = useRealDb ? realDb! : other;
        final title = useRealDb ? 'ערוך השולחן' : 'בראשית';
        final userDb = MyDatabase.untrusted(path);
        final userRepository = SeforimRepository(userDb);
        final repo = FindRefRepository(
          isReferenceBooksCacheLoaded: () => true,
          searchReferenceBooks: (_, {int limit = 50}) => [],
          getTocEntriesForReference: (_, _, {queryTokens}) async => [],
          getAllAltTocFlatEntries: () async => [],
          openUserBooksRepository: () async => userRepository,
        );
        addTearDown(() async {
          repo.dispose();
          worker.reset();
          userDb.close();
          AttachedFindRefWorker.callTimeout = previousTimeout;
          await registry.closeAll();
          AttachedLibraryRegistry.instance = previousRegistry;
          await dir.delete(recursive: true);
        });
        final warm = await repo.findRefs(title, includePersonalBooks: true);
        expect(
          warm.where((r) => r.source == BookSource.user).map((r) => r.title),
          contains(title),
        );
        final normalizations =
            FindRefRepository.debugSecondaryNameNormalizations;
        final count = await worker.run(
          path,
          immutable: false,
          version: 'v',
          job: _bookCount,
        );
        expect(count, greaterThan(0));
        final started = ReceivePort();
        addTearDown(started.close);
        AttachedFindRefWorker.callTimeout = const Duration(milliseconds: 100);
        final active = worker.run(
          path,
          immutable: false,
          version: 'v',
          job: _hang(started.sendPort),
          background: true,
        );
        final failure = expectLater(active, throwsA(isA<TimeoutException>()));
        await started.first;
        final waiting = worker.run(
          other,
          immutable: false,
          version: 'v',
          job: _bookCount,
        );
        final waitingFailure = expectLater(
          waiting.timeout(const Duration(seconds: 2)),
          throwsA(isA<StateError>()),
        );
        final cached = await repo.findRefs(title, includePersonalBooks: true);
        expect(cached.map((r) => r.title), contains(title));
        await failure;
        await waitingFailure;
        AttachedFindRefWorker.callTimeout = previousTimeout;
        expect(
          await worker.run(
            other,
            immutable: false,
            version: 'v',
            job: _bookCount,
          ),
          greaterThan(0),
        );
        expect(
          await worker.run(
            path,
            immutable: false,
            version: 'v',
            job: _bookCount,
          ),
          count,
        );
        final recovered = await repo.findRefs(
          title,
          includePersonalBooks: true,
        );
        expect(recovered.map((r) => r.title), contains(title));
        expect(
          FindRefRepository.debugSecondaryNameNormalizations,
          normalizations,
        );
      },
      skip: useRealDb && realDb == null,
    );
  }
}
