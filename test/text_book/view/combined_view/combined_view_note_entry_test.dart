import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:otzaria/text_book/utils/reading_segments.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../test_helpers/memory_cache_provider.dart';

const _lines = ['פסקה ראשונה', 'פסקה שניה', 'פסקה שלישית'];

const _genesisLines = [
  "<h1>בראשית</h1>",
  "<h2>פרק א</h2>",
  "(א) <big>בְּ</big>רֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָֽרֶץ׃",
  "(ב) וְהָאָ֗רֶץ הָיְתָ֥ה תֹ֙הוּ֙ וָבֹ֔הוּ וְחֹ֖שֶׁךְ עַל־פְּנֵ֣י תְה֑וֹם וְר֣וּחַ אֱלֹהִ֔ים מְרַחֶ֖פֶת עַל־פְּנֵ֥י הַמָּֽיִם׃",
  "(ג) וַיֹּ֥אמֶר אֱלֹהִ֖ים יְהִ֣י א֑וֹר וַֽיְהִי־אֽוֹר׃",
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  testWidgets('continuous note after headings and wrapped pointed text', (
    tester,
  ) async {
    final fixture = await _pumpView(
      tester,
      continuous: true,
      selectedIndex: 2,
      data: _genesisLines,
      book: TextBook(title: 'בראשית', id: 1),
    );
    final note = await _openNote(
      tester,
      fixture,
      _textBox(tester, '(ג)').center,
    );
    expect(note.lineNumber, 5);
    expect(note.bookId, 'בראשית');
    expect(note.selectedText, anyOf(isNull, isEmpty));
  });

  for (final continuous in [false, true]) {
    for (final selectedIndex in <int?>[null, 0, 1]) {
      for (final selection in ['none', 'cleared', 'active', 'outside']) {
        testWidgets(
          'note at clicked source line: continuous=$continuous, '
          'selectedIndex=$selectedIndex, selection=$selection',
          (tester) async {
            final fixture = await _pumpView(
              tester,
              continuous: continuous,
              selectedIndex: selectedIndex,
            );
            var click = _textBox(tester, 'שניה').center;
            if (selection != 'none') {
              await _selectText(tester, 'שניה', 'שניה');
              expect(fixture.selectedText?.trim(), 'שניה');
              expect(fixture.selectedLine, 1);
              if (selection == 'cleared') {
                await tester.sendKeyEvent(LogicalKeyboardKey.escape);
                await tester.pump();
                expect(fixture.selectedText, isNull);
              } else if (selection == 'outside') {
                click = _textBox(tester, 'שלישית').center;
              }
            }

            final note = await _openNote(tester, fixture, click);
            expect(note.lineNumber, 2);
            expect(note.bookId, 'ספר בדיקה');
            expect(
              note.selectedText,
              selection == 'active' || selection == 'outside'
                  ? 'שניה'
                  : anyOf(isNull, isEmpty),
            );
          },
        );
      }
    }

    testWidgets('cross-paragraph selection keeps its start: $continuous', (
      tester,
    ) async {
      final fixture = await _pumpView(tester, continuous: continuous);
      await _selectText(tester, 'ראשונה', 'שלישית');
      expect(fixture.selectedLine, 0);
      expect(fixture.selectedText, contains('שניה'));
      final selectedText = fixture.selectedText!.trim();
      final note = await _openNote(
        tester,
        fixture,
        _textBox(tester, 'שניה').center,
      );
      expect(note.lineNumber, 1);
      expect(note.selectedText, selectedText);
      expect(note.bookId, 'ספר בדיקה');
    });

    testWidgets('keyboard selection keeps its start: $continuous', (
      tester,
    ) async {
      final fixture = await _pumpView(tester, continuous: continuous);
      await _selectText(tester, 'שניה', 'שניה');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(fixture.selectedLine, 1);
      expect(fixture.selectedText, startsWith('שניה'));
      final selectedText = fixture.selectedText!.trim();
      final note = await _openNote(
        tester,
        fixture,
        _textBox(tester, 'שניה').center,
      );
      expect(note.lineNumber, 2);
      expect(note.selectedText, selectedText);
      expect(note.bookId, 'ספר בדיקה');
    });
  }
}

class _Fixture {
  final _PersonalNotesBloc notesBloc;
  String? selectedText;
  int? selectedLine;

  _Fixture(this.notesBloc);
}

Future<_Fixture> _pumpView(
  WidgetTester tester, {
  required bool continuous,
  int? selectedIndex,
  List<String> data = _lines,
  TextBook? book,
}) async {
  book ??= TextBook(title: 'ספר בדיקה');
  final bloc = _TextBookBloc(
    _loadedState(
      book: book,
      availableCommentators: const [],
      selectedIndex: selectedIndex,
      continuous: continuous,
      data: data,
    ),
  );
  final settingsBloc = _SettingsBloc(SettingsState.initial());
  final notesBloc = _PersonalNotesBloc(const PersonalNotesState.initial());
  final fixture = _Fixture(notesBloc);
  final tab = TextBookTab(book: book, index: 0);
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
      locale: const Locale('he', 'IL'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('he', 'IL')],
      home: MultiBlocProvider(
        providers: [
          BlocProvider<TextBookBloc>.value(value: bloc),
          BlocProvider<PersonalNotesBloc>.value(value: notesBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
        ],
        child: Scaffold(
          body: CombinedView(
            data: data,
            openBookCallback: (_) {},
            openLeftPaneTab: (_, {searchText}) {},
            textSize: 18,
            showCommentaryAsExpansionTiles: true,
            onOpenPersonalNotes: () {},
            onSelectedTextChanged: (text, line, column) {
              fixture.selectedText = text;
              fixture.selectedLine = line;
            },
            tab: tab,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return fixture;
}

Rect _textBox(WidgetTester tester, String text) {
  final paragraph = tester.allRenderObjects
      .whereType<RenderParagraph>()
      .firstWhere(
        (paragraph) => paragraph.text.toPlainText().contains(text),
      );
  final offset = paragraph.text.toPlainText().indexOf(text);
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + text.length),
      )
      .first
      .toRect();
  return Rect.fromPoints(
    paragraph.localToGlobal(box.topLeft),
    paragraph.localToGlobal(box.bottomRight),
  );
}

Future<void> _selectText(WidgetTester tester, String start, String end) async {
  final first = _textBox(tester, start);
  final last = _textBox(tester, end);
  final gesture = await tester.startGesture(
    Offset(first.right - 1, first.center.dy),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.moveTo(Offset(last.left + 1, last.center.dy));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<StartCreatingPersonalNote> _openNote(
  WidgetTester tester,
  _Fixture fixture,
  Offset position,
) async {
  await tester.tapAt(
    position,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  expect(find.text('הערה'), findsOneWidget);
  await tester.tap(find.text('הערה'));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  return fixture.notesBloc.received
      .whereType<StartCreatingPersonalNote>()
      .single;
}

TextBookLoaded _loadedState({
  required TextBook book,
  required List<String> availableCommentators,
  int? selectedIndex,
  required bool continuous,
  required List<String> data,
}) {
  return TextBookLoaded(
    book: book,
    showLeftPane: false,
    content: data,
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
    visibleIndices: List.generate(data.length, (index) => index),
    selectedIndex: selectedIndex,
    selectedIndices: selectedIndex == null ? const {} : {selectedIndex},
    continuousReadingMode: continuous,
    readingSegments: buildReadingSegments(data, continuous: continuous),
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
