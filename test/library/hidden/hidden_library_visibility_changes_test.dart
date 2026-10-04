import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/windowing/settings_sync.dart';
import 'package:otzaria/library/hidden/hidden_library_selection.dart';
import 'package:otzaria/library/hidden/hidden_library_store.dart';

import '../../test_helpers/memory_cache_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
    SettingsSync.instance.applyLocally = (key, value) async {};
  });

  tearDown(() => SettingsSync.instance.applyLocally = null);

  test('fires for a change in this window', () async {
    var fired = 0;
    final subscription = const HiddenLibraryStore().visibilityChanges.listen(
      (_) => fired++,
    );
    addTearDown(subscription.cancel);

    await const HiddenLibraryStore().save(
      const HiddenLibrarySelection(bookKeys: {'ספר'}),
    );

    expect(fired, 1);
  });

  test('fires for the hidden library settings of another window', () async {
    var fired = 0;
    final subscription = const HiddenLibraryStore().visibilityChanges.listen(
      (_) => fired++,
    );
    addTearDown(subscription.cancel);

    await SettingsSync.instance.applyAuthoritativeValues({
      HiddenLibraryStore.bookKeysSetting: 'x',
      HiddenLibraryStore.categoryPathsSetting: 'y',
      'key-unrelated-setting': true,
    });
    await Future<void>.delayed(Duration.zero);

    expect(fired, 2);
  });

  test('stops after the subscription is cancelled', () async {
    var fired = 0;
    final subscription = const HiddenLibraryStore().visibilityChanges.listen(
      (_) => fired++,
    );
    await subscription.cancel();

    await const HiddenLibraryStore().save(
      const HiddenLibrarySelection(bookKeys: {'ספר אחר'}),
    );

    expect(fired, 0);
  });
}
