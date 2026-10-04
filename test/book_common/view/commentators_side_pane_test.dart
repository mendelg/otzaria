import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/book_common/view/commentators_side_pane.dart';

void main() {
  testWidgets('shows the three tabs and switches between their contents', (
    tester,
  ) async {
    final controller = TabController(length: 3, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentatorsSidePane(
            controller: controller,
            navigation: const Text('תוכן ניווט'),
            selection: const Text('תוכן מפרשים'),
            search: const Text('תוכן חיפוש'),
          ),
        ),
      ),
    );

    expect(find.text('ניווט'), findsOneWidget);
    expect(find.text('מפרשים'), findsOneWidget);
    expect(find.text('חיפוש'), findsOneWidget);
    expect(find.text('תוכן ניווט'), findsOneWidget);

    controller.animateTo(2);
    await tester.pumpAndSettle();
    expect(find.text('תוכן חיפוש'), findsOneWidget);
  });
}
