import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/services/plugin_installer_service.dart';

class _FakeRepo extends Mock implements PluginRegistryRepository {
  @override
  Future<List<InstalledPlugin>> getAllPlugins() async => [];
  @override
  Future<List<InstalledPlugin>> getDevelopmentPlugins() async => [];
}

/// מחזיר PreparedInstall קבוע — הטסט בודק את ההעברה לבלוק, לא את הפריקה.
class _StubInstaller extends PluginInstallerService {
  _StubInstaller(this.prepared) : super(repository: _FakeRepo());

  final PreparedInstall prepared;

  @override
  Future<PreparedInstall> prepareInstall(
    String archivePath, {
    bool forceOverwrite = false,
  }) async => prepared;
}

PluginManifest _manifest() => PluginManifest.fromJson({
  'schemaVersion': 1,
  'id': 'test.plugin',
  'name': 'תוסף',
  'version': '1.0.1',
  'entrypoint': 'index.html',
  'permissions': ['app.info.read', 'notes.read'],
});

void main() {
  test(
    'InstallPluginRequested מעביר הרשאות קודמות ומקור יוזמה אל ה-state',
    () async {
      const previousGrants = {'app.info.read': false};
      final bloc = PluginSystemBloc(
        repository: _FakeRepo(),
        installerService: _StubInstaller(
          PreparedInstall(
            _manifest(),
            '/tmp/staged',
            true,
            previousVersion: '1.0.0',
            previousGrantedPermissions: previousGrants,
          ),
        ),
      );
      addTearDown(bloc.close);

      final pending = bloc.stream.firstWhere(
        (s) => s is PluginSystemInstallRequiresPermissions,
      );
      bloc.add(const InstallPluginRequested('/tmp/plugin.zip'));

      final requiresPermissions =
          (await pending) as PluginSystemInstallRequiresPermissions;
      expect(requiresPermissions.previousVersion, '1.0.0');
      expect(requiresPermissions.previousGrantedPermissions, previousGrants);
      expect(requiresPermissions.isUserInitiated, isFalse);
    },
  );

  test('שומר התקנה יזומה במסלול התקנת קובץ', () async {
    final bloc = PluginSystemBloc(
      repository: _FakeRepo(),
      installerService: _StubInstaller(
        PreparedInstall(_manifest(), '/tmp/staged', false),
      ),
    );
    addTearDown(bloc.close);

    final pending = bloc.stream.firstWhere(
      (s) => s is PluginSystemInstallRequiresPermissions,
    );
    bloc.add(
      const InstallPluginRequested(
        '/tmp/plugin.otzplugin',
        isUserInitiated: true,
      ),
    );

    final state = (await pending) as PluginSystemInstallRequiresPermissions;
    expect(state.isUserInitiated, isTrue);
  });
}
