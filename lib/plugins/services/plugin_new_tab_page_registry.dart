import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/services/plugin_page_launcher.dart';

/// Controls what the reader's "+" (new tab) button opens.
///
/// Registration belongs to the plugin, not to one WebView instance. This is
/// intentional: a startup/background instance may register the target and then
/// be disposed, while the "+" must continue to open the plugin's visible page.
/// A later registration wins; when no registration remains, the new-tab button is hidden.
class PluginNewTabPageRegistry extends ChangeNotifier {
  static final PluginNewTabPageRegistry instance = PluginNewTabPageRegistry._();
  PluginNewTabPageRegistry._();

  final Map<String, int> _registrations = {};
  int _sequence = 0;

  void register(String pluginId) {
    _registrations[pluginId] = ++_sequence;
    notifyListeners();
  }

  void remove(String pluginId) {
    if (_registrations.remove(pluginId) != null) {
      notifyListeners();
    }
  }

  bool get hasActiveRegistration => _registrations.isNotEmpty;

  String? get activePluginId {
    if (_registrations.isEmpty) return null;
    String? selected;
    var newest = -1;
    for (final entry in _registrations.entries) {
      if (entry.value > newest) {
        newest = entry.value;
        selected = entry.key;
      }
    }
    return selected;
  }

  /// Opens the registered plugin page. With no registration the button is hidden.
  void open() {
    final pluginId = activePluginId;
    if (pluginId == null) return;
    PluginPageLauncher.instance.open(
      pluginId,
      topic: 'plugin.page_opened',
      payload: const {'source': 'newTabButton'},
    );
  }
}
