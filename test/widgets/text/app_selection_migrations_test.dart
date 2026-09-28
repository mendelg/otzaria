import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/ui_snack.dart' show navigatorKey, UiSnack;
import 'package:otzaria/core/info/app_info_service.dart';
import 'package:otzaria/core/info/info_topic.dart';
import 'package:otzaria/core/info/view/app_info_dialog.dart';
import 'package:otzaria/app_report/view/widgets/app_report_preview_section.dart';
import 'package:otzaria/plugins/view/plugin_webview_failed_view.dart';
import 'package:otzaria/tools/acronyms_dictionary/widgets/acronym_result_card.dart';
import 'package:otzaria/tools/aramaic_dictionary/widgets/aramaic_result_card.dart';
import 'package:otzaria/widgets/misc/app_selection_area.dart';

Future<void> _rightClickAt(WidgetTester tester, Offset position) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.addPointer(location: position);
  addTearDown(gesture.removePointer);
  await gesture.down(position);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _selectAll(WidgetTester tester) async {
  tester
      .state<SelectableRegionState>(find.byType(SelectableRegion))
      .selectAll();
  await tester.pump();
}

void _expectOtzariaMenuOnly(WidgetTester tester) {
  expect(find.text('העתק'), findsOneWidget);
  expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('פרטי האפליקציה נשארים לבחירה ומעתיקים דרך תפריט אוצריא', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final report = AppInfoReport(
      topic: InfoTopic.app,
      generatedAt: DateTime(2026, 9, 28),
      sections: const {
        'app': {
          'version': '0.9.97',
          'buildNumber': '99702',
          'installType': 'portable',
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: AppInfoDialogContent(report: report)),
        ),
      ),
    );

    expect(find.byType(AppSelectionArea), findsOneWidget);
    await _selectAll(tester);
    await _rightClickAt(tester, tester.getCenter(find.text('0.9.97+99702')));
    _expectOtzariaMenuOnly(tester);

    await tester.tap(find.text('העתק'));
    await tester.pumpAndSettle();
    expect(clipboardText, contains('0.9.97+99702'));
    UiSnack.hide();
  });

  testWidgets('טקסט בכרטיס ראשי תיבות נשאר לבחירה עם תפריט אוצריא', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: AcronymResultCard(acronym: 'ר"ת', meanings: ['ראשי תיבות']),
          ),
        ),
      ),
    );

    expect(find.byType(AppSelectionArea), findsOneWidget);
    await _selectAll(tester);
    await _rightClickAt(tester, tester.getCenter(find.text('ר"ת')));
    _expectOtzariaMenuOnly(tester);
  });

  testWidgets('טקסט בכרטיס מילון ארמי נשאר לבחירה עם תפריט אוצריא', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: AramaicResultCard(
              aramaic: 'אבא',
              hebrew: 'אב',
              isHebrewToAramaic: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppSelectionArea), findsOneWidget);
    await _selectAll(tester);
    await _rightClickAt(tester, tester.getCenter(find.text('אבא')));
    _expectOtzariaMenuOnly(tester);
  });

  testWidgets('תצוגת דוח התקלה נשארת ניתנת לבחירה במקטע האבחון', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AppReportPreviewSection(
              diagnostics: const {'version': '0.9.97'},
              errorLog: null,
              includeDiagnostics: true,
              includeErrorLog: false,
              onDiagnosticsChanged: (_) {},
              onErrorLogChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('הצג את מה שיישלח'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('0.9.97'));
    expect(find.byType(AppSelectionArea), findsOneWidget);
    await _selectAll(tester);
    await _rightClickAt(
      tester,
      tester.getCenter(find.textContaining('0.9.97')),
    );
    _expectOtzariaMenuOnly(tester);
  });

  testWidgets('פרטי שגיאת WebView נשארים לבחירה עם תפריט אוצריא', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: PluginWebViewFailedView(
            onRetry: _noop,
            errorDetails: 'WebView initialization failed',
          ),
        ),
      ),
    );

    await tester.tap(find.text('פרטי השגיאה'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSelectionArea), findsOneWidget);
    await _selectAll(tester);
    await _rightClickAt(
      tester,
      tester.getCenter(find.text('WebView initialization failed')),
    );
    _expectOtzariaMenuOnly(tester);
  });
}

void _noop() {}
