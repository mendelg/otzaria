import 'package:flutter/material.dart';
import 'package:otzaria/theme/app_tokens.dart';

/// כפתור קטן בסרגל התוצאות של חלונית חיפוש (הקודמת/הבאה/עצירה).
/// [onPressed] null מציג את הכפתור כמושבת.
class SearchResultNavButton extends StatelessWidget {
  const SearchResultNavButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppTokens.borderRadiusAll,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isEnabled
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHigh,
            borderRadius: AppTokens.borderRadiusAll,
            border: Border.all(
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isEnabled
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
