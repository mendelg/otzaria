import 'dart:async';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/library/models/library.dart';

import '../../helpers/memory_settings_cache.dart';

void main() {
  late DataRepository repository;

  setUp(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
    repository = DataRepository();
  });

  test('קוראים במקביל חולקים Future אחד, ובנייה שנכשלה אינה נשמרת', () async {
    final build = Completer<Library>();
    repository.library = build.future;

    final first = repository.library;
    final second = repository.library;
    expect(identical(first, second), isTrue);

    build.completeError(StateError('catalog failed'));
    await expectLater(first, throwsStateError);
    await expectLater(second, throwsStateError);
    expect(repository.cachedLibraryFutureForTesting, isNull);
  });

  test('כשל של Future שהוחלף אינו מוחק את החדש', () async {
    final stale = Completer<Library>();
    repository.library = stale.future;
    final fresh = Future.value(Library(categories: []));
    repository.library = fresh;

    stale.completeError(StateError('stale failed'));
    await expectLater(stale.future, throwsStateError);
    expect(identical(repository.cachedLibraryFutureForTesting, fresh), isTrue);
  });
}
