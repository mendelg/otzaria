import 'dart:math' as math;

/// קנה המידה של תמונת התצוגה המקדימה של עמוד: הרזולוציה המוצגת בפועל,
/// מעוגלת למעלה לחזקת 2 כדי ששינוי זום קטן לא ירנדר מחדש את כל העמודים.
///
/// [displayScale] - פיקסלים פיזיים לנקודת PDF כפי שהעמוד מוצג כעת.
/// [threshold] - התקרה של pdfrx; מעליה pdfrx משלים אריחים חדים לאזור הנראה.
/// [sizeThreshold] - כמו ב-pdfrx: עמוד שצלע שלו ארוכה מזה מוגבל לצלע זו בפיקסלים.
double pdfPreviewRenderingScale({
  required double displayScale,
  required double threshold,
  required double pageWidth,
  required double pageHeight,
  required double sizeThreshold,
}) {
  final longestEdge = math.max(pageWidth, pageHeight);
  final cap = longestEdge > sizeThreshold
      ? sizeThreshold / longestEdge
      : threshold;
  if (!displayScale.isFinite || displayScale <= 0) return cap;
  final quantized = math
      .pow(2, (math.log(displayScale) / math.ln2).ceil())
      .toDouble();
  return math.min(quantized, cap);
}
