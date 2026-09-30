import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/core/app_runtime_reset.dart';
import 'package:otzaria/core/windowing/multi_window_service.dart';
import 'package:otzaria/plugins/utils/plugin_safe_mode.dart';
import 'package:otzaria/plugins/view/webview_environment_holder.dart';
import 'package:otzaria/widgets/controls/bar_button.dart';
import 'package:otzaria/widgets/dialogs/confirmation_dialog.dart';
import 'package:otzaria/widgets/misc/restart_widget.dart';

/// Restarts the app in place with safe mode turned [on] or off, after the
/// user confirms.
Future<void> restartWithSafeMode(
  BuildContext context, {
  required bool on,
}) async {
  final confirmed = await showConfirmationDialog(
    context: context,
    title: on ? 'הפעלה מחדש במצב בטוח' : 'יציאה ממצב בטוח',
    content: on
        ? 'אוצריא תופעל מחדש בלי אף תוסף, עד להפעלה מחדש רגילה. '
              'ההגדרות של התוספים אינן משתנות.'
        : 'אוצריא תופעל מחדש כרגיל, והתוספים הפעילים ייטענו שוב.',
    confirmText: 'הפעל מחדש',
  );
  if (confirmed != true || !context.mounted) return;
  await PluginSafeMode.set(on);
  await resetRuntimeStateForAppRestart();
  if (!context.mounted) return;
  MultiWindowService.restartPeers();
  RestartWidget.restartApp(
    context,
    afterRestart: WebViewEnvironmentHolder.disposeForAppRestart,
  );
}

/// Title bar chip shown while safe mode is on; tapping it offers a normal
/// restart.
class SafeModeTitleBarIndicator extends StatelessWidget {
  const SafeModeTitleBarIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PluginSafeMode.active,
      builder: (context, active, _) => !active
          ? const SizedBox.shrink()
          : BarButton.text(
              text: 'מצב בטוח',
              icon: FluentIcons.shield_24_regular,
              onPressed: () => restartWithSafeMode(context, on: false),
            ),
    );
  }
}
