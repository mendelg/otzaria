import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/navigation/view/startup_work_gate.dart';

void main() {
  group('StartupWorkGate', () {
    test('does not start before library and settings are ready', () {
      final gate = StartupWorkGate();

      expect(gate.consumeStartPermission(), isFalse);

      gate.markLibraryLoaded();
      expect(gate.consumeStartPermission(), isFalse);

      gate.markIndexingDecisionResolved(expectIndexing: false);
      expect(gate.consumeStartPermission(), isTrue);
      expect(gate.consumeStartPermission(), isFalse);
    });

    test('waits for indexing to finish before allowing startup work', () {
      final gate = StartupWorkGate();

      gate.markLibraryLoaded();
      gate.markIndexingDecisionResolved(expectIndexing: true);

      expect(gate.consumeStartPermission(), isFalse);

      gate.markIndexingRunning(false);
      expect(gate.consumeStartPermission(), isTrue);
      expect(gate.consumeStartPermission(), isFalse);
    });

    test('blocks startup work while indexing is still running', () {
      final gate = StartupWorkGate();

      gate.markLibraryLoaded();
      gate.markIndexingDecisionResolved(expectIndexing: false);
      gate.markIndexingRunning(true);

      expect(gate.consumeStartPermission(), isFalse);

      gate.markIndexingRunning(false);
      expect(gate.consumeStartPermission(), isTrue);
    });

    test('סיור: סנכרון רקע מחכה גם לכל תור האינדוקס של העדכון המאוחר', () {
      final gate = StartupWorkGate()..markLibraryLoaded();
      gate.holdDeferredWork();
      gate.markIndexingDecisionResolved(expectIndexing: true);
      gate.markStartupIndexingSettled();
      gate.markStartupIndexingBatchPending();
      gate.releaseDeferredWork();

      expect(gate.consumeStartPermission(), isFalse);
      gate.markIndexingRunning(true);
      gate.markIndexingRunning(false);
      expect(gate.consumeStartPermission(), isFalse);

      gate.markStartupIndexingSettled();
      expect(gate.consumeStartPermission(), isTrue);
    });
  });
}
