import 'package:flutter/material.dart';
import 'package:otzaria/theme/app_colors.dart';

/// היפוך צבעים — מה שעמוד PDF עובר במצב כהה.
const pdfInvertColors = ColorFilter.mode(Colors.white, BlendMode.difference);

/// המסנן שמוחל על ציור תוכן העמודים בלבד. בבהיר אין מסנן כלל; שכבת סינון
/// על כל הצפיין מרכיבה מחדש את כל שטח התצוגה בכל פריים.
ColorFilter? pdfPageColorFilter(Brightness brightness) =>
    brightness == Brightness.dark ? pdfInvertColors : null;

/// צבע "נייר" ריק, כפי שעמוד לבן נראה אחרי [pdfPageColorFilter].
Color pdfPageColor(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.black : AppColors.pageWhite;
