import 'dart:async';

import 'package:flutter/foundation.dart';

/// שער "הקורא קודם": סופר טאבי PDF בטעינה (PdfBookLoading ב-PdfBookBloc), כדי
/// שעבודת רקע על PDF (outline, אינדוקס) תפנה את ה-worker היחיד של pdfrx.
class PdfViewerActivity {
  PdfViewerActivity._();

  static final PdfViewerActivity instance = PdfViewerActivity._();

  /// מספר ה-viewers שנמצאים כעת בטעינה.
  final ValueNotifier<int> loadingCount = ValueNotifier<int>(0);

  void begin() => loadingCount.value++;

  void end() {
    assert(loadingCount.value > 0, 'end() ללא begin() תואם');
    if (loadingCount.value > 0) loadingCount.value--;
  }

  /// חוזר מיד כשאין viewer בטעינה; אחרת ממתין עד שכולם יסיימו או עד
  /// [timeout] — כך עבודת הרקע לעולם אינה נחסמת לצמיתות.
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (loadingCount.value == 0) return;
    final idle = Completer<void>();
    void listener() {
      if (loadingCount.value == 0 && !idle.isCompleted) idle.complete();
    }

    loadingCount.addListener(listener);
    try {
      await idle.future.timeout(timeout, onTimeout: () {});
    } finally {
      loadingCount.removeListener(listener);
    }
  }
}
