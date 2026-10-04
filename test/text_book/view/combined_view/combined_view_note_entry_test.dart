import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/book_common/models/commentator_group.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
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
import 'package:otzaria/text_book/text_book_repository.dart';
import 'package:otzaria/text_book/view/combined_view/combined_book_screen.dart';
import 'package:otzaria/widgets/misc/app_context_menu.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../test_helpers/memory_cache_provider.dart';

const _lines = ['שורה א', 'שורה ב', 'שורה ג'];

/// The note action of the main text context menu attaches the note to the
/// paragraph that was right-clicked when nothing is selected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  testWidgets('a note without a selection goes to the clicked paragraph', (
    tester,
  ) async {
    final bloc = _TextBookBloc(
      _loadedState(
        book: TextBook(title: 'ספר בדיקה'),
        availableCommentators: const [],
        // A paragraph selected earlier must not take the note.
        selectedIndex: 0,
      ),
    );
    final settingsBloc = _SettingsBloc(SettingsState.initial());
    final notesBloc = _PersonalNotesBloc(const PersonalNotesState.initial());
    final tab = TextBookTab(book: TextBook(title: 'ספר בדיקה'), index: 0);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
      tab.dispose();
      await bloc.close();
      await settingsBloc.close();
      await notesBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TextBookBloc>.value(value: bloc),
            BlocProvider<PersonalNotesBloc>.value(value: notesBloc),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
          ],
          child: Scaffold(
            body: CombinedView(
              data: _lines,
              openBookCallback: (_) {},
              openLeftPaneTab: (_, {searchText}) {},
              textSize: 18,
              showCommentaryAsExpansionTiles: true,
              onOpenPersonalNotes: () {},
              tab: tab,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final regionFinder = find.byType(AppContextMenuRegion).at(2);
    final region = tester.widget<AppContextMenuRegion>(regionFinder);
    final entries = region.menuBuilder(
      tester.element(regionFinder),
      tester.getCenter(regionFinder),
    );
    final note = entries.first.iconRowActions!.firstWhere(
      (action) => action.label == 'הערה',
    );
    note.onTap!();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    final started = notesBloc.received
        .whereType<StartCreatingPersonalNote>()
        .single;
    expect(started.lineNumber, 3);
  });
}

TextBookLoaded _loadedState({
  required TextBook book,
  required List<String> availableCommentators,
  int? selectedIndex,
}) {
  return TextBookLoaded(
    book: book,
    showLeftPane: false,
    content: _lines,
    fontSize: 18,
    showSplitView: false,
    showPageShapeView: false,
    activeCommentators: const [],
    commentatorGroups: [
      if (availableCommentators.isNotEmpty)
        CommentatorGroup(title: 'ראשונים', commentators: availableCommentators),
    ],
    availableCommentators: availableCommentators,
    links: const [],
    visibleLinks: const [],
    linksByLine: {
      1: [for (final title in availableCommentators) _commentaryLink(title)],
    },
    tableOfContents: const [],
    removeNikud: false,
    visibleIndices: const [0, 1, 2],
    selectedIndex: selectedIndex,
    pinLeftPane: false,
    searchText: '',
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );
}

Link _commentaryLink(String title) => Link(
  heRef: '',
  index1: 1,
  path2: title,
  index2: 1,
  connectionType: 'commentary',
);

class _TextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  @override
  late final TextBookRepository repository = _TextBookRepository(
    (state as TextBookLoaded).availableCommentators,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TextBookRepository implements TextBookRepository {
  _TextBookRepository(this.commentators);

  final List<String> commentators;

  @override
  Future<List<Link>> getBookLinksInRange(
    TextBook book, {
    required int startIndex,
    required int endIndex,
    Iterable<String>? targetBookTitles,
  }) async => [for (final title in commentators) _commentaryLink(title)];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PersonalNotesBloc extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _PersonalNotesBloc(super.initialState) {
    on<PersonalNotesEvent>((event, emit) => received.add(event));
  }

  final List<PersonalNotesEvent> received = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _SettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
