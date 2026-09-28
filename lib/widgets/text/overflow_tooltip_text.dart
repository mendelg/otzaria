import 'package:flutter/material.dart';

/// בודק האם הטקסט גולש מעבר למספר השורות המרבי ברוחב הנתון.
bool textOverflows({
  required BuildContext context,
  required String text,
  required TextStyle style,
  required int maxLines,
  required double maxWidth,
  TextAlign textAlign = TextAlign.start,
  TextDirection? textDirection,
}) {
  final textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: textAlign,
    textDirection: textDirection ?? Directionality.of(context),
    maxLines: maxLines,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);
  return textPainter.didExceedMaxLines;
}

/// ווידג'ט טקסט שעוטף את עצמו ב-[Tooltip] אך ורק כאשר הטקסט נקטע ([TextOverflow.ellipsis]).
///
/// כשהטקסט נכנס במלואו במגבלות הרוחב, מרונדר [Text] רגיל ללא תקורה או טולטיפ מיותר.
class OverflowTooltipText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign textAlign;
  final String? tooltipMessage;
  final Duration waitDuration;

  const OverflowTooltipText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.tooltipMessage,
    this.waitDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ?? DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasOverflow =
            constraints.maxWidth.isFinite &&
            constraints.maxWidth > 0 &&
            textOverflows(
              context: context,
              text: text,
              style: resolvedStyle,
              maxLines: maxLines,
              maxWidth: constraints.maxWidth,
              textAlign: textAlign,
            );

        final child = Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: resolvedStyle,
        );

        if (!hasOverflow) {
          return child;
        }

        return Tooltip(
          message: tooltipMessage ?? text,
          waitDuration: waitDuration,
          child: child,
        );
      },
    );
  }
}
