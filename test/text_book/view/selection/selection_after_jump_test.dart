import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/combined_view/combined_book_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../test_helpers/memory_cache_provider.dart';

const _title = 'ספר בדיקה';

final _content = <String>[
  for (var i = 0; i < 80; i++) 'פסקה$i ${List.filled(6, 'מילה$i').join(' ')}',
];

class _TestTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TestTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPersonalNotesBloc
    extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _TestPersonalNotesBloc(super.initialState) {
    on<PersonalNotesEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  Future<TextBookTab> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = TextBookLoaded(
      book: TextBook(title: _title),
      showLeftPane: false,
      content: _content,
      fontSize: 18,
      showSplitView: false,
      showPageShapeView: false,
      activeCommentators: const [],
      commentatorGroups: const [],
      availableCommentators: const [],
      links: const [],
      visibleLinks: const [],
      linksByLine: const {},
      tableOfContents: const [],
      removeNikud: false,
      visibleIndices: const [0],
      selectedIndex: null,
      pinLeftPane: false,
      searchText: '',
      scrollController: ItemScrollController(),
      positionsListener: ItemPositionsListener.create(),
    );
    final textBookBloc = _TestTextBookBloc(state);
    final personalNotesBloc = _TestPersonalNotesBloc(
      const PersonalNotesState.initial(),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());
    final tab = TextBookTab(book: TextBook(title: _title), index: 0);
    addTearDown(textBookBloc.close);
    addTearDown(personalNotesBloc.close);
    addTearDown(settingsBloc.close);
    addTearDown(tab.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('he', 'IL'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('he', 'IL')],
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TextBookBloc>.value(value: textBookBloc),
            BlocProvider<PersonalNotesBloc>.value(value: personalNotesBloc),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
          ],
          child: Scaffold(
            body: CombinedView(
              data: _content,
              openBookCallback: (_) {},
              openLeftPaneTab: (_, {searchText}) {},
              textSize: 18,
              showCommentaryAsExpansionTiles: false,
              tab: tab,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    return tab;
  }

  Rect lineRect(WidgetTester tester, int lineIndex) =>
      tester.getRect(find.byKey(ValueKey('html_${_title}_$lineIndex')));

  /// ה-registrar של ה-Scrollable — הילדים שלו הם פריטי הרשימה, בסדר שבו
  /// אזור הבחירה סורק אותם.
  MultiSelectableSelectionContainerDelegate scrollableRegistrar(
    WidgetTester tester,
  ) {
    final ctx = tester.element(find.byType(SliverList).first);
    return SelectionContainer.maybeOf(ctx)!
        as MultiSelectableSelectionContainerDelegate;
  }

  // קפיצה של הרשימה מאפסת את היסט הגלילה; הבחירה אסור שתנחת על טקסט אחר
  // באותו גובה על המסך (issue #1589).
  Future<void> selectThenMove(
    WidgetTester tester, {
    required double scrolledBy,
    required Future<void> Function(TextBookTab tab) move,
  }) async {
    final tab = await pumpView(tester);
    if (scrolledBy > 0) {
      unawaited(
        tab.mainOffsetController.animateScroll(
          offset: scrolledBy,
          duration: const Duration(milliseconds: 100),
        ),
      );
      await tester.pumpAndSettle();
    }
    final line = lineRect(tester, 8);
    final word = Offset(line.right - 20, line.center.dy);
    await tester.tapAt(word, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(word, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 400));

    String selected() => scrollableRegistrar(
      tester,
    ).selectables.map((s) => s.getSelectedContent()?.plainText ?? '').join();
    expect(selected(), 'מילה8');

    await move(tab);
    await tester.pumpAndSettle();

    expect(selected(), anyOf(isEmpty, 'מילה8'));
  }

  for (final scrolledBy in [0.0, 150.0]) {
    testWidgets('jumpTo אחרי גלילה של $scrolledBy', (tester) async {
      await selectThenMove(
        tester,
        scrolledBy: scrolledBy,
        move: (tab) async => tab.scrollController.jumpTo(index: 50),
      );
    });
    testWidgets('scrollTo אחרי גלילה של $scrolledBy', (tester) async {
      await selectThenMove(
        tester,
        scrolledBy: scrolledBy,
        move: (tab) async => unawaited(
          tab.scrollController.scrollTo(
            index: 50,
            duration: const Duration(milliseconds: 300),
          ),
        ),
      );
    });
  }

  testWidgets('עיגון מחדש אחרי גלילה של יותר ממסך', (tester) async {
    await selectThenMove(
      tester,
      scrolledBy: 150,
      move: (tab) async {
        unawaited(
          tab.mainOffsetController.animateScroll(
            offset: 600,
            duration: const Duration(milliseconds: 100),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });
}
