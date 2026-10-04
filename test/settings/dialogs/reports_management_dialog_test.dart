import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/app_report/services/app_report_service.dart';
import 'package:otzaria/core/user_state/pending_report_store.dart';
import 'package:otzaria/core/user_state/user_state_database.dart';
import 'package:otzaria/settings/dialogs/reports_management_dialog.dart';
import 'package:otzaria/settings/engine/settings_engine_exports.dart';
import 'package:otzaria/settings/panels/app_reports_panel.dart';
import 'package:otzaria/settings/panels/error_reports_panel.dart';
import 'package:otzaria/settings/panels/plugin_reports_panel.dart';
import 'package:otzaria/plugins/services/plugin_report_service.dart';
import 'package:otzaria/services/direct_error_report_service.dart';

class _FakeSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _FakeSettingsBloc() : super(SettingsState.initial());
}

class _MemoryCacheProvider extends CacheProvider {
  final Map<String, Object?> _values = {};

  @override
  Future<void> init() async {}

  @override
  Set getKeys() => _values.keys.toSet();

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  bool? getBool(String key, {bool? defaultValue}) =>
      _values[key] as bool? ?? defaultValue;

  @override
  double? getDouble(String key, {double? defaultValue}) =>
      _values[key] as double? ?? defaultValue;

  @override
  int? getInt(String key, {int? defaultValue}) =>
      _values[key] as int? ?? defaultValue;

  @override
  String? getString(String key, {String? defaultValue}) =>
      _values[key] as String? ?? defaultValue;

  @override
  T? getValue<T>(String key, {T? defaultValue}) =>
      _values[key] as T? ?? defaultValue;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> removeAll() async => _values.clear();

  @override
  Future<void> setBool(String key, bool? value) async => _values[key] = value;

  @override
  Future<void> setDouble(String key, double? value) async =>
      _values[key] = value;

  @override
  Future<void> setInt(String key, int? value) async => _values[key] = value;

  @override
  Future<void> setObject<T>(String key, T? value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String? value) async =>
      _values[key] = value;
}

void main() {
  setUpAll(() async {
    await Settings.init(cacheProvider: _MemoryCacheProvider());
  });

  Future<void> pumpDialog(WidgetTester tester, ReportsTab tab) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BlocProvider<SettingsBloc>.value(
        value: _FakeSettingsBloc(),
        child: MaterialApp(
          locale: const Locale('he', 'IL'),
          home: Scaffold(body: ReportsManagementDialog(initialTab: tab)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('opens on the requested tab, with one panel per tab', (
    tester,
  ) async {
    await pumpDialog(tester, ReportsTab.app);
    expect(find.text('הדיווחים שלך'), findsOneWidget);
    expect(find.byType(AppReportsPanel), findsOneWidget);
    expect(find.byType(ErrorReportsPanel), findsNothing);

    await tester.tap(find.text('תוספים'));
    await tester.pumpAndSettle();
    expect(find.byType(PluginReportsPanel), findsOneWidget);

    await tester.tap(find.text('טעויות בספרים'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorReportsPanel), findsOneWidget);
  });

  test('ReportCounts.load sums saved reports per kind', () async {
    final tmp = Directory.systemTemp.createTempSync('otzaria_report_counts_');
    final db = UserStateDatabase.openAt(
      '${tmp.path}${Platform.pathSeparator}user_state.db',
    );
    addTearDown(() {
      db.close();
      tmp.deleteSync(recursive: true);
    });
    final store = PendingReportStore(database: db);
    await store.add(DirectErrorReportService.pendingKind, const {});
    await store.add(DirectErrorReportService.pendingKind, const {});
    await store.add(PluginReportService.pendingKind, const {});
    await store.add(AppReportService.sentKind, const {});
    await store.add(DirectErrorReportService.sentKind, const {});

    final counts = await ReportCounts.load(reportStore: store);
    expect(counts.books, 2);
    expect(counts.app, 0);
    expect(counts.plugins, 1);
    expect(counts.sent, 2);
  });
}
