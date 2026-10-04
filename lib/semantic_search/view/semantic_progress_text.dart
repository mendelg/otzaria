import 'package:flutter/widgets.dart';
import 'package:otzaria/core/messages/semantic_search_messages.dart';
import 'package:otzaria/semantic_search/models/semantic_availability.dart';
import 'package:otzaria/settings/l10n/settings_l10n_exports.dart';

/// תווית השלב המתורגמת, כמו [SemanticSearchMessages.progressLabel]:
/// "שלב 2 מתוך 3 — מוריד את נתוני החיפוש (12%)".
String semanticProgressText(
  BuildContext context,
  SemanticDownloadProgress progress,
) {
  final action = context.settingsText(
    SemanticSearchMessages.stepAction(progress.item),
  );
  final label = progress.stepCount > 1
      ? context.settingsText(
          SemanticSearchMessages.stepTemplate,
          args: {
            'step': '${progress.step}',
            'count': '${progress.stepCount}',
            'action': action,
          },
        )
      : action;
  final percent = SemanticSearchMessages.progressPercent(progress);
  return percent == null
      ? label
      : context.settingsText(
          SemanticSearchMessages.percentTemplate,
          args: {'label': label, 'percent': percent},
        );
}
