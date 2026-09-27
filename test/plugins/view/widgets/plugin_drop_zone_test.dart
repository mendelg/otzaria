import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/services/plugin_file_drop_service.dart';
import 'package:otzaria/plugins/view/widgets/plugin_drop_zone.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/settings/engine/settings_state.dart';

class _RecordingPluginSystemBloc
    extends Bloc<PluginSystemEvent, PluginSystemState>
    implements PluginSystemBloc {
  _RecordingPluginSystemBloc() : super(PluginSystemInitial());

  final List<PluginSystemEvent> added = [];

  @override
  void add(PluginSystemEvent event) => added.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState);
}

class _StubSettingsRepository implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// יחס פיקסלים גדול מ-1 כדי לוודא את ההמרה מפיקסלים פיזיים ללוגיים.
const double _ratio = 2.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingPluginSystemBloc pluginBloc;
  late PluginFileDropService service;

  setUp(() {
    pluginBloc = _RecordingPluginSystemBloc();
    service = PluginFileDropService();
    PluginFileDropService.instance = service;
  });

  tearDown(() => pluginBloc.close());

  // אזור הקליטה תופס 100x100 לוגיים בפינה השמאלית-עליונה של חלון 400x400.
  Future<void> pumpZone(WidgetTester tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 400),
          devicePixelRatio: _ratio,
        ),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<PluginSystemBloc>.value(value: pluginBloc),
            BlocProvider<SettingsBloc>.value(
              value: _TestSettingsBloc(SettingsState.initial()),
            ),
          ],
          child: RepositoryProvider<SettingsRepository>.value(
            value: _StubSettingsRepository(),
            child: MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: PluginDropZone(child: Container()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  WindowsFileDropEvent at({
    List<String> paths = const [],
    required double logicalX,
    required double logicalY,
  }) => WindowsFileDropEvent(
    paths: paths,
    x: logicalX * _ratio,
    y: logicalY * _ratio,
  );

  testWidgets('גרירת ‎.otzplugin‎ מעל האזור מציגה חיווי שחרור', (tester) async {
    await pumpZone(tester);

    service.handleDrag(
      at(paths: ['C:/x.otzplugin'], logicalX: 50, logicalY: 50),
    );
    await tester.pump();

    expect(find.text('שחרר כדי להתקין את התוסף'), findsOneWidget);
  });

  testWidgets('גרירה מחוץ לאזור אינה מציגה חיווי', (tester) async {
    await pumpZone(tester);

    service.handleDrag(
      at(paths: ['C:/x.otzplugin'], logicalX: 300, logicalY: 300),
    );
    await tester.pump();

    expect(find.text('שחרר כדי להתקין את התוסף'), findsNothing);
  });

  testWidgets('קובץ שאינו תוסף אינו מציג חיווי', (tester) async {
    await pumpZone(tester);

    service.handleDrag(at(paths: ['C:/x.txt'], logicalX: 50, logicalY: 50));
    await tester.pump();

    expect(find.text('שחרר כדי להתקין את התוסף'), findsNothing);
  });

  testWidgets('הגרירה מאושרת ל-native רק מעל האזור', (tester) async {
    await pumpZone(tester);

    // ה-enter הראשון מגיע לפני שהאזור סימן את עצמו, ולכן עדיין אינו מאושר.
    service.handleDrag(
      at(paths: ['C:/x.otzplugin'], logicalX: 50, logicalY: 50),
    );
    expect(
      service.handleDrag(
        at(paths: ['C:/x.otzplugin'], logicalX: 50, logicalY: 50),
      ),
      isTrue,
    );

    expect(service.handleDrag(at(logicalX: 300, logicalY: 300)), isFalse);
  });

  testWidgets('קובץ שאינו תוסף אינו מאושר', (tester) async {
    await pumpZone(tester);

    service.handleDrag(at(paths: ['C:/x.txt'], logicalX: 50, logicalY: 50));

    expect(
      service.handleDrag(at(paths: ['C:/x.txt'], logicalX: 50, logicalY: 50)),
      isFalse,
    );
  });

  testWidgets('סיום הגרירה מנקה את מצב האזור', (tester) async {
    await pumpZone(tester);

    service.handleDrag(
      at(paths: ['C:/x.otzplugin'], logicalX: 50, logicalY: 50),
    );
    await tester.pump();
    expect(find.text('שחרר כדי להתקין את התוסף'), findsOneWidget);

    service.handleLeave();
    await tester.pump();
    expect(find.text('שחרר כדי להתקין את התוסף'), findsNothing);
  });

  testWidgets('שחרור בתוך האזור מבקש התקנה', (tester) async {
    await pumpZone(tester);

    await service.handleDrop(
      at(paths: ['C:/x.otzplugin'], logicalX: 50, logicalY: 50),
    );
    await tester.pumpAndSettle();

    expect(pluginBloc.added, hasLength(1));
    final event = pluginBloc.added.single as InstallPluginRequested;
    expect(event.archivePath, 'C:/x.otzplugin');
    expect(event.isUserInitiated, isTrue);
  });

  testWidgets('שחרור מחוץ לאזור אינו מבקש התקנה', (tester) async {
    await pumpZone(tester);

    await service.handleDrop(
      at(paths: ['C:/x.otzplugin'], logicalX: 300, logicalY: 300),
    );
    await tester.pumpAndSettle();

    expect(pluginBloc.added, isEmpty);
  });

  testWidgets('שחרור קובץ שאינו תוסף אינו מבקש התקנה', (tester) async {
    await pumpZone(tester);

    await service.handleDrop(
      at(paths: ['C:/x.txt'], logicalX: 50, logicalY: 50),
    );
    await tester.pumpAndSettle();

    expect(pluginBloc.added, isEmpty);
  });
}
