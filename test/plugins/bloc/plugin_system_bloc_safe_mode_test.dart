import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/declarative/services/declarative_plugin_host_service.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/utils/plugin_safe_mode.dart';

InstalledPlugin _plugin() => InstalledPlugin(
  pluginId: 'p1',
  name: 'P1',
  version: '1.0.0',
  installPath: '/tmp/p1',
  entrypointPath: 'index.html',
  enabled: false,
  pinned: false,
  manifest: PluginManifest.fromJson({
    'id': 'p1',
    'name': 'P1',
    'version': '1.0.0',
    'entrypoint': 'index.html',
  }),
  installedAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _FakeRepo implements PluginRegistryRepository {
  final saved = <InstalledPlugin>[];

  @override
  Future<List<InstalledPlugin>> getAllPlugins() async => [_plugin()];

  @override
  Future<InstalledPlugin?> getPlugin(String id) async => _plugin();

  @override
  Future<void> savePlugin(InstalledPlugin plugin) async => saved.add(plugin);

  @override
  Future<List<InstalledPlugin>> getDevelopmentPlugins() async => [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDeclarativeHost implements DeclarativePluginHost {
  int syncs = 0;

  @override
  Future<void> syncPlugins(List<InstalledPlugin> plugins) async => syncs++;

  @override
  void removePlugin(String pluginId) {}

  @override
  Future<void> readerBookChanged(Book? book, {required String context}) async {}

  @override
  Future<void> dispatchAction(
    String pluginId,
    CompiledDeclarativeAction action,
  ) async {}

  @override
  Future<void> dispatchSelectionAction(
    String pluginId,
    Map<String, dynamic> actionTemplate,
    Map<String, dynamic> selectionPayload,
  ) async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late _FakeDeclarativeHost host;
  late PluginSystemBloc bloc;

  setUp(() {
    PluginSafeMode.active.value = true;
    repo = _FakeRepo();
    host = _FakeDeclarativeHost();
    bloc = PluginSystemBloc(repository: repo, declarativeHost: host);
  });

  tearDown(() async {
    await bloc.close();
    PluginSafeMode.resetForTesting();
  });

  Future<void> send(PluginSystemEvent event) async {
    bloc.add(event);
    await pumpEventQueue(times: 200);
  }

  test('loading lists the plugins without syncing them', () async {
    await send(LoadPlugins());

    expect(bloc.state, isA<PluginSystemLoaded>());
    expect((bloc.state as PluginSystemLoaded).plugins, hasLength(1));
    // A sync would treat the disabled plugins as removed and unpublish data.
    expect(host.syncs, 0);
  });

  test('enable and disable requests write nothing', () async {
    await send(const EnablePluginRequested('p1'));
    await send(const DisablePluginRequested('p1'));

    expect(repo.saved, isEmpty);
  });
}
