import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:path/path.dart' as p;

/// Safe mode: no plugin loads for the rest of this process, while every
/// plugin keeps its saved enabled state.
///
/// Turned on by `--safe-mode`, by holding Shift while Otzaria starts on
/// Windows, or from settings; a normal restart turns it off.
class PluginSafeMode {
  PluginSafeMode._();

  static final ValueNotifier<bool> active = ValueNotifier(false);

  static bool get isActive => active.value;

  static const String _markerFileName = 'safe_mode_session.json';

  /// Called once from main(); reads the flag only, with no file access.
  static void initFromArgs(List<String> args) {
    active.value = args.any(isSafeModeFlag);
  }

  /// Records an active safe mode for secondary windows. Called once data paths
  /// are configured; does nothing otherwise, and a stale marker from another
  /// process is ignored by its process id.
  static Future<void> publishForSecondaryWindows() async {
    if (isActive) await set(true);
  }

  /// Secondary windows are isolates of the same process: they follow the
  /// main window through a marker file that records its process id.
  static Future<void> initForSecondaryWindow() async {
    try {
      final file = await _markerFile();
      if (!file.existsSync()) return;
      final data = jsonDecode(await file.readAsString());
      active.value = data is Map && data['pid'] == pid;
    } catch (error) {
      debugPrint('Safe mode marker read failed: $error');
    }
  }

  static Future<void> set(bool value) async {
    active.value = value;
    try {
      final file = await _markerFile();
      if (value) {
        await file.writeAsString(jsonEncode({'pid': pid}));
      } else if (file.existsSync()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('Safe mode marker write failed: $error');
    }
  }

  static Future<File> _markerFile() async =>
      File(p.join(await AppPaths.getDataRootPath(), _markerFileName));

  @visibleForTesting
  static void resetForTesting() => active.value = false;
}

/// Whether [arg] is `--safe-mode` (also `/safe-mode`, bare, or with `_`).
bool isSafeModeFlag(String arg) =>
    arg
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^(--|/)'), '')
        .replaceAll('_', '-') ==
    'safe-mode';
