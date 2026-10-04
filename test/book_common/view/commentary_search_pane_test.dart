import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/book_common/utils/commentary_search_utils.dart';
import 'package:otzaria/book_common/view/commentary_search_pane.dart';

void main() {
  testWidgets('counts the results and moves between them', (tester) async {
    final controller = TextEditingController(text: 'שלום');
    final focusNode = FocusNode();
    final total = ValueNotifier(3);
    final current = ValueNotifier(0);
    final snippets = ValueNotifier<List<CommentarySearchSnippet>>(const []);
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
      total.dispose();
      current.dispose();
      snippets.dispose();
    });
    var previous = 0;
    var next = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentarySearchPane(
            controller: controller,
            focusNode: focusNode,
            hintText: 'חיפוש במפרשים...',
            totalResults: total,
            currentResult: current,
            snippets: snippets,
            onPrevious: () => previous++,
            onNext: () => next++,
            onSnippetTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('תוצאה 1 מתוך 3'), findsOneWidget);

    current.value = 1;
    await tester.pump();
    expect(find.text('תוצאה 2 מתוך 3'), findsOneWidget);

    await tester.tap(find.byIcon(FluentIcons.chevron_up_24_regular));
    await tester.tap(find.byIcon(FluentIcons.chevron_down_24_regular));
    expect(previous, 1);
    expect(next, 1);

    total.value = 0;
    await tester.pump();
    expect(find.textContaining('מתוך'), findsNothing);
  });
}
