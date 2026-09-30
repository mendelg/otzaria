import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/diagnostics/developer_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseDiagnosticsLaunchMode', () {
    DiagnosticsLaunchMode parse(
      List<String> args, [
      Map<String, String> env = const {},
    ]) => parseDiagnosticsLaunchMode(args, env);

    test('is off by default', () {
      expect(parse(const []), DiagnosticsLaunchMode.off);
      expect(parse(const ['otzaria://open']), DiagnosticsLaunchMode.off);
    });

    test('reads the command-line flag in its accepted spellings', () {
      for (final flag in [
        '--dev-diagnostics',
        '/dev-diagnostics',
        '--DEV_DIAGNOSTICS',
      ]) {
        expect(parse([flag]), DiagnosticsLaunchMode.panel, reason: flag);
      }
      expect(parse(['--dev-diagnostics=log']), DiagnosticsLaunchMode.logOnly);
    });

    test('falls back to the environment variable', () {
      expect(
        parse(const [], {devDiagnosticsEnv: '1'}),
        DiagnosticsLaunchMode.panel,
      );
      expect(
        parse(const [], {devDiagnosticsEnv: 'log'}),
        DiagnosticsLaunchMode.logOnly,
      );
      expect(
        parse(const [], {devDiagnosticsEnv: '0'}),
        DiagnosticsLaunchMode.off,
      );
    });
  });

  test('computeFrameStats summarizes the window', () {
    final stats = computeFrameStats(
      const [
        FrameSample(2, 1, 5),
        FrameSample(4, 1, 8),
        FrameSample(30, 4, 40),
      ],
      window: const Duration(seconds: 2),
      slowTotal: 7,
    );
    expect(stats.framesPerSecond, 2);
    expect(stats.buildAvgMs, 12.0);
    expect(stats.buildMaxMs, 30.0);
    expect(stats.rasterMaxMs, 4.0);
    expect(stats.slowInWindow, 1);
    expect(stats.slowTotal, 7);
  });

  group('DeveloperDiagnostics', () {
    late File output;
    late List<String> errorLog;
    final diagnostics = DeveloperDiagnostics.instance;

    setUp(() {
      errorLog = [];
      output = File(
        '${Directory.systemTemp.createTempSync('diag').path}/out.jsonl',
      );
      diagnostics
        ..resetForTesting()
        ..outputPath = output.path
        ..errorLogWriter = errorLog.add;
    });

    tearDown(diagnostics.resetForTesting);

    List<Map<String, dynamic>> records() => [
      for (final line in output.readAsLinesSync())
        jsonDecode(line) as Map<String, dynamic>,
    ];

    test('nothing is collected or written while off', () {
      diagnostics.initFromLaunch(const [], environment: const {});
      expect(diagnostics.isCollecting, isFalse);
      expect(diagnostics.panelVisible.value, isFalse);
      expect(output.existsSync(), isFalse);
    });

    test('log-only launch collects without showing the panel', () async {
      diagnostics.initFromLaunch(const [
        '--dev-diagnostics=log',
      ], environment: const {});
      expect(diagnostics.isCollecting, isTrue);
      expect(diagnostics.panelVisible.value, isFalse);

      await diagnostics.snapshot();
      final types = records().map((r) => r['type']).toList();
      expect(types, ['session', 'snapshot']);
    });

    test('toggling off a launch request stops collecting', () {
      diagnostics
        ..initFromLaunch(const ['--dev-diagnostics'], environment: const {})
        ..toggle();
      expect(diagnostics.isCollecting, isFalse);
      expect(diagnostics.panelVisible.value, isFalse);

      diagnostics.toggle();
      expect(diagnostics.isCollecting, isTrue);
      expect(diagnostics.panelVisible.value, isTrue);
    });

    test('snapshot includes the app context', () async {
      diagnostics.contextProvider = () => {'screen': 'reading', 'tabs': 3};
      diagnostics.toggle();
      await diagnostics.snapshot();

      final snapshot = records().firstWhere((r) => r['type'] == 'snapshot');
      expect(snapshot['context'], {'screen': 'reading', 'tabs': 3});
      expect(snapshot, contains('rssMb'));
      expect(errorLog.single, startsWith('=== Developer snapshot'));
    });

    test('toggling it off stops collecting', () {
      diagnostics.toggle();
      expect(diagnostics.isCollecting, isTrue);
      expect(diagnostics.panelVisible.value, isTrue);
      diagnostics.performanceOverlay.value = true;
      diagnostics.toggle();

      expect(diagnostics.isCollecting, isFalse);
      expect(diagnostics.panelVisible.value, isFalse);
      expect(diagnostics.performanceOverlay.value, isFalse);
    });
  });
}
