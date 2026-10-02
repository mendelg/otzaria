import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_new_tab_page_registry.dart';

void main() {
  group('PluginNewTabPageRegistry', () {
    const first = 'test.new-tab.first';
    const second = 'test.new-tab.second';
    final registry = PluginNewTabPageRegistry.instance;

    tearDown(() {
      registry.remove(first);
      registry.remove(second);
    });

    test('is hidden until a plugin registers', () {
      registry.remove(first);
      registry.remove(second);
      expect(registry.hasActiveRegistration, isFalse);
      expect(registry.activePluginId, isNull);
    });

    test('latest registration wins and removing it restores previous one', () {
      registry.register(first);
      expect(registry.hasActiveRegistration, isTrue);
      expect(registry.activePluginId, first);

      registry.register(second);
      expect(registry.activePluginId, second);

      registry.remove(second);
      expect(registry.hasActiveRegistration, isTrue);
      expect(registry.activePluginId, first);

      registry.remove(first);
      expect(registry.hasActiveRegistration, isFalse);
      expect(registry.activePluginId, isNull);
    });

    test('notifies listeners only when visibility/registration can change', () {
      var notifications = 0;
      void listener() => notifications++;
      registry.addListener(listener);
      addTearDown(() => registry.removeListener(listener));

      registry.register(first);
      registry.register(second);
      registry.remove(second);
      registry.remove('test.new-tab.missing');

      expect(notifications, 3);
    });
  });
}
