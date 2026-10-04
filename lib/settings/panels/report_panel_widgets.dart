import 'package:flutter/material.dart';
import 'package:otzaria/settings/l10n/settings_l10n_exports.dart';

/// Pieces shared by the book, plugin and app report panels.

/// The action row under a saved or sent report.
Widget buildReportActions({required List<Widget> children}) {
  return Padding(
    padding: const EdgeInsets.only(right: 56, left: 16, bottom: 12),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: children,
      ),
    ),
  );
}

/// Dims [child] and blocks taps on it while [enabled] is false.
Widget buildManagedActionButton({
  required bool enabled,
  required Widget child,
}) {
  return IgnorePointer(
    ignoring: !enabled,
    child: Opacity(opacity: enabled ? 1 : 0.45, child: child),
  );
}

/// The history keeps a fixed number of reports, so the total is shown apart.
String sentReportsSubtitle(
  BuildContext context, {
  required int shown,
  required int total,
}) {
  if (shown == 0) {
    return context.settingsText('עדיין אין דיווחים שנשלחו דרך המערכת');
  }
  if (total > shown) {
    return context.settingsText(
      'נשלחו {total} דיווחים, מוצגים {shown} האחרונים',
      args: {'total': total, 'shown': shown},
    );
  }
  return context.settingsText(
    'נשמרו {count} דיווחים שנשלחו',
    args: {'count': shown},
  );
}
