import 'package:flutter/services.dart';

// עוקף לבאג מנוע Flutter (flutter/flutter#178945): סמן בשורת RTL שמסתיימת
// ב-\n מוסט; \r לפני ה-\n מונע זאת. משמש רק לטקסט המוצג ב-RtlTextField.

final RegExp _anyCarriageReturn = RegExp(r'\r\n?');

/// הופך כל \r\n ו-\r בודד ל-\n. \r בודד נשמר כשבירת שורה ולא נמחק.
String collapseHardBreaks(String text) =>
    text.contains('\r') ? text.replaceAll(_anyCarriageReturn, '\n') : text;

bool _isBareNewline(String text, int i) =>
    text[i] == '\n' && (i == 0 || text[i - 1] != '\r');

/// offset שנמצא בין \r ל-\n של אותו שבר זז לפני השבר, כדי לא להיתקע בתוכו.
int snapOffsetOutOfCrlf(String text, int offset) {
  if (offset > 0 &&
      offset < text.length &&
      text[offset - 1] == '\r' &&
      text[offset] == '\n') {
    return offset - 1;
  }
  return offset;
}

/// מרחיב כל \n בודד ל-\r\n, וממפה בחירה ו-composing באותו מעבר על הטקסט.
TextEditingValue expandValue(TextEditingValue value) {
  final text = value.text;
  var hasBareNewline = false;
  for (var i = 0; i < text.length && !hasBareNewline; i++) {
    hasBareNewline = _isBareNewline(text, i);
  }
  if (!hasBareNewline) return value;

  final sel = value.selection;
  final comp = value.composing;
  final buffer = StringBuffer();
  var inserted = 0;
  int? mappedBase, mappedExtent, mappedCompStart, mappedCompEnd;
  for (var i = 0; i <= text.length; i++) {
    if (sel.baseOffset == i) mappedBase = i + inserted;
    if (sel.extentOffset == i) mappedExtent = i + inserted;
    if (comp.start == i) mappedCompStart = i + inserted;
    if (comp.end == i) mappedCompEnd = i + inserted;
    if (i == text.length) break;
    if (_isBareNewline(text, i)) {
      buffer.write('\r\n');
      inserted++;
    } else {
      buffer.write(text[i]);
    }
  }
  return TextEditingValue(
    text: buffer.toString(),
    selection: sel.copyWith(
      baseOffset: mappedBase ?? sel.baseOffset,
      extentOffset: mappedExtent ?? sel.extentOffset,
    ),
    composing: TextRange(
      start: mappedCompStart ?? comp.start,
      end: mappedCompEnd ?? comp.end,
    ),
  );
}

/// הופך ערך מורחב בחזרה ל"נקי" (ראו [collapseHardBreaks]), באותו מעבר יחיד.
TextEditingValue collapseValue(TextEditingValue value) {
  final text = value.text;
  if (!text.contains('\r')) return value;
  final sel = value.selection;
  final comp = value.composing;
  final targetBase = snapOffsetOutOfCrlf(text, sel.baseOffset);
  final targetExtent = snapOffsetOutOfCrlf(text, sel.extentOffset);
  final targetCompStart = snapOffsetOutOfCrlf(text, comp.start);
  final targetCompEnd = snapOffsetOutOfCrlf(text, comp.end);
  final buffer = StringBuffer();
  var removed = 0;
  int? mappedBase, mappedExtent, mappedCompStart, mappedCompEnd;
  for (var i = 0; i <= text.length; i++) {
    if (targetBase == i) mappedBase = i - removed;
    if (targetExtent == i) mappedExtent = i - removed;
    if (targetCompStart == i) mappedCompStart = i - removed;
    if (targetCompEnd == i) mappedCompEnd = i - removed;
    if (i == text.length) break;
    final ch = text[i];
    if (ch != '\r') {
      buffer.write(ch);
    } else if (i + 1 < text.length && text[i + 1] == '\n') {
      removed++;
    } else {
      buffer.write('\n');
    }
  }
  return TextEditingValue(
    text: buffer.toString(),
    selection: sel.copyWith(
      baseOffset: mappedBase ?? sel.baseOffset,
      extentOffset: mappedExtent ?? sel.extentOffset,
    ),
    composing: TextRange(
      start: mappedCompStart ?? comp.start,
      end: mappedCompEnd ?? comp.end,
    ),
  );
}

/// מרחיב בכל עריכה, כדי ש-\n שהוקלד זה עתה לא יוצג אפילו פריים אחד בלי \r.
/// בזמן composing של IME לא נוגעים (שינוי באמצע מבטל את המילה המוצעת).
class HardBreakInputFormatter extends TextInputFormatter {
  const HardBreakInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.composing.isValid ? newValue : expandValue(newValue);
}

/// מריץ formatters של הקורא על הטקסט הנקי, כדי שה-\r הפנימי לא ישפיע
/// על מגבלות אורך או תווים.
class CleanSpaceFormatterAdapter extends TextInputFormatter {
  const CleanSpaceFormatterAdapter(this.inner);

  final List<TextInputFormatter> inner;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleanOld = collapseValue(oldValue);
    var cleanNew = collapseValue(newValue);
    for (final formatter in inner) {
      cleanNew = formatter.formatEditUpdate(cleanOld, cleanNew);
    }
    return expandValue(cleanNew);
  }
}
