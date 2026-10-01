import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/personal_notes/repository/personal_notes_repository.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_adapter.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/services/plugin_page_launcher.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tools/calendar/bloc/calendar_cubit.dart';
import 'package:otzaria/utils/navigation/book_open_coordinator.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';

class _MockHistoryBloc extends Mock implements HistoryBloc {}

class _MockTabsBloc extends Mock implements TabsBloc {}

class _MockNavigationBloc extends Mock implements NavigationBloc {}

class _MockCalendarCubit extends Mock implements CalendarCubit {}

class _MockWorkspaceBloc extends Mock implements WorkspaceBloc {}

class _MockSearchRepository extends Mock implements SearchRepository {}

class _MockPersonalNotesRepository extends Mock
    implements PersonalNotesRepository {}

class _MockBookOpenCoordinator extends Mock implements BookOpenCoordinator {}

class _MockPluginRegistryRepository extends Mock
    implements PluginRegistryRepository {}

InstalledPlugin _buildInstalledPlugin() {
  return InstalledPlugin(
    pluginId: 'test.plugin',
    name: 'Test Plugin',
    version: '1.0.0',
    installPath: '/',
    entrypointPath: 'index.html',
    enabled: true,
    pinned: true,
    manifest: PluginManifest(
      schemaVersion: 1,
      id: 'test.plugin',
      name: 'Test Plugin',
      version: '1.0.0',
      description: '',
      author: '',
      homepage: '',
      entrypoint: 'index.html',
      minAppVersion: '1.0.0',
      sdkVersion: '1.x',
      permissions: const ['ui.feedback'],
      networkEnabled: false,
      networkAllowlist: const [],
      toolTabTitle: 'Test Plugin',
      toolTabOrder: 1,
      defaultPinned: true,
      publishedDataTypes: const [],
    ),
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

/// בדיקות ל-`ui.show*` עם אירועי לחיצה (`tapEvent`/`tapPayload`).
///
/// בקובץ נפרד מ-plugin_bridge_adapter_test.dart: `testWidgets` מאתחל
/// TestWidgetsFlutterBinding שמחליף את HttpOverrides הגלובלי — ושובר שם את
/// בדיקות שרת הקבצים שמשתמשות ב-HTTP אמיתי.
void main() {
  late List<String> dispatchedTopics;
  late List<String> dispatchedPluginIds;
  late List<Map<String, dynamic>> dispatchedPayloads;
  late List<String?> dispatchedInstanceIds;
  late PluginBridgeAdapter adapter;

  setUp(() {
    dispatchedTopics = [];
    dispatchedPluginIds = [];
    dispatchedPayloads = [];
    dispatchedInstanceIds = [];
    adapter = PluginBridgeAdapter(
      _buildInstalledPlugin(),
      instanceId: 'tab-7',
      dependencies: PluginBridgeDependencies(
        historyBloc: _MockHistoryBloc(),
        tabsBloc: _MockTabsBloc(),
        navigationBloc: _MockNavigationBloc(),
        calendarCubit: _MockCalendarCubit(),
        workspaceBloc: _MockWorkspaceBloc(),
        searchRepository: _MockSearchRepository(),
        personalNotesRepository: _MockPersonalNotesRepository(),
        bookOpenCoordinator: _MockBookOpenCoordinator(),
        themePayloadBuilder: () => <String, dynamic>{},
        showConfirmDialog: ({required title, required content}) async => true,
        showWarningDialog:
            ({required title, required content, required subtitle}) async =>
                true,
        dispatchEventToPlugin: (pluginId, topic, payload, {instanceId}) async {
          dispatchedPluginIds.add(pluginId);
          dispatchedTopics.add(topic);
          dispatchedPayloads.add(payload);
          dispatchedInstanceIds.add(instanceId);
        },
      ),
      pluginRepository: _MockPluginRegistryRepository(),
    );
  });

  tearDown(UiSnack.hide);

  Future<void> pumpSnackHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
  }

  testWidgets('לחיצה על הודעה עם tapPayload משגרת ui.messageClicked', (
    tester,
  ) async {
    await pumpSnackHost(tester);
    await adapter.execute('ui', 'showMessage', {
      'message': 'הסנכרון הסתיים',
      'tapPayload': {'syncId': 42},
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('הסנכרון הסתיים'));
    await tester.pumpAndSettle();

    expect(dispatchedPluginIds, ['test.plugin']);
    expect(dispatchedTopics, ['ui.messageClicked']);
    expect(dispatchedPayloads, [
      {
        'payload': {'syncId': 42},
      },
    ]);
    // הלחיצה חוזרת למופע שהציג את ההודעה — לא לבחירת הדיספצ'ר.
    expect(dispatchedInstanceIds, ['tab-7']);
    expect(find.text('הסנכרון הסתיים'), findsNothing);
  });

  testWidgets('tapEvent מותאם מחליף את שם האירוע (גם ב-showSuccess)', (
    tester,
  ) async {
    await pumpSnackHost(tester);
    await adapter.execute('ui', 'showSuccess', {
      'message': 'נשמר',
      'tapEvent': 'my.customEvent',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('נשמר'));
    await tester.pumpAndSettle();

    expect(dispatchedTopics, ['my.customEvent']);
    expect(dispatchedPayloads, [
      {'payload': null},
    ]);
  });

  testWidgets('הודעה בלי tapEvent/tapPayload אינה לחיצה', (tester) async {
    await pumpSnackHost(tester);
    await adapter.execute('ui', 'showError', {'message': 'שגיאה'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('שגיאה'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(dispatchedTopics, isEmpty);
    expect(find.text('שגיאה'), findsOneWidget);

    // סגירה בתוך גוף הבדיקה — אחרת טיימר ההסתרה האוטומטית נשאר תלוי.
    UiSnack.hide();
    await tester.pump();
  });

  testWidgets('notifications.showInApp עם tapPayload — לחיצה משגרת אירוע', (
    tester,
  ) async {
    await pumpSnackHost(tester);
    await adapter.execute('notifications', 'showInApp', {
      'message': 'יש עדכונים',
      'type': 'info',
      'tapPayload': {'updates': 2},
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('יש עדכונים'));
    await tester.pumpAndSettle();

    expect(dispatchedTopics, ['ui.messageClicked']);
    expect(dispatchedPayloads, [
      {
        'payload': {'updates': 2},
      },
    ]);
  });

  testWidgets('tapOpenPlugin: לחיצה מנווטת לדף התוסף', (tester) async {
    final openedPluginIds = <String>[];
    PluginPageLauncher.instance.navigator = openedPluginIds.add;
    addTearDown(() {
      PluginPageLauncher.instance.navigator = null;
      // ניקוי האירוע הממתין שנרשם ל-launcher (הדף לא נטען בבדיקה).
      PluginPageLauncher.instance.markPageClosed('test.plugin');
    });

    await pumpSnackHost(tester);
    await adapter.execute('notifications', 'showInApp', {
      'message': 'יש עדכונים — לחצו לפתיחה',
      'type': 'info',
      'tapOpenPlugin': true,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('יש עדכונים — לחצו לפתיחה'));
    await tester.pumpAndSettle();

    expect(openedPluginIds, ['test.plugin']);
    // הניווט פותח את הדף; האירוע נמסר דרך ה-launcher, לא דרך dispatch ישיר.
    expect(dispatchedTopics, isEmpty);
  });

  test('tapEvent עם תווים לא חוקיים נדחה', () async {
    await expectLater(
      adapter.execute('ui', 'showMessage', {
        'message': 'הודעה',
        'tapEvent': "bad'); alert(1); ('",
      }),
      throwsException,
    );
  });
}
