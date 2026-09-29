import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/sqlite_memory_release.dart';
import 'package:otzaria/core/user_state/user_state_database.dart';
import 'package:otzaria/data/data_providers/cache_database_holder.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/data_providers/user_books_database_holder.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/personal_notes/storage/personal_notes_database.dart';
import 'package:otzaria/plugins/storage/plugin_system_database.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqliteMemoryPressureObserver', () {
    late int calls;
    late SqliteMemoryPressureObserver observer;

    setUp(() {
      calls = 0;
      observer = SqliteMemoryPressureObserver(release: () async => calls++);
    });

    testWidgets('לחץ זיכרון מהמערכת משחרר', (tester) async {
      tester.binding.addObserver(observer);
      addTearDown(() => tester.binding.removeObserver(observer));

      tester.binding.handleMemoryPressure();
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets('מעבר לרקע משחרר פעם אחת; איבוד פוקוס לא', (tester) async {
      tester.binding.addObserver(observer);
      addTearDown(() => tester.binding.removeObserver(observer));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(calls, 0, reason: 'inactive = איבוד פוקוס בדסקטופ');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(calls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(calls, 2);
    });

    test('שחרור שעדיין רץ אינו מופעל שוב', () async {
      final gate = Completer<void>();
      final slow = SqliteMemoryPressureObserver(
        release: () {
          calls++;
          return gate.future;
        },
      );

      slow.didHaveMemoryPressure();
      slow.didHaveMemoryPressure();
      expect(calls, 1);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      slow.didHaveMemoryPressure();
      expect(calls, 2);
    });
  });

  test('releaseSqliteMemory לא פותח חיבורים סגורים', () async {
    await releaseSqliteMemory();

    expect(SqliteDataProvider.instance.repository, isNull);
    expect(CacheDatabaseHolder.instance.repositoryIfInitialized, isNull);
    expect(UserBooksDatabaseHolder.instance.repositoryIfInitialized, isNull);
    expect(UserStateDatabase.instance.openDatabase, isNull);
    expect(PersonalNotesDatabase.instance.openDatabase, isNull);
    expect(PluginSystemDatabase.instance.openDatabase, isNull);
  });

  test('shrinkMemoryIfOpen רץ רק על חיבור פתוח ואינו פותח', () async {
    final dir = Directory.systemTemp.createTempSync('shrink_memory');
    addTearDown(() => dir.deleteSync(recursive: true));
    final database = MyDatabase.withPath(p.join(dir.path, 'cache.db'));

    expect(database.shrinkMemoryIfOpen(), isFalse);
    expect(database.isOpen, isFalse);

    await database.database;
    expect(database.shrinkMemoryIfOpen(), isTrue);

    database.close();
    expect(database.shrinkMemoryIfOpen(), isFalse);
    expect(database.isOpen, isFalse);
  });
}
