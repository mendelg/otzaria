import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:otzaria/text_book/utils/reading_segments.dart';
import 'package:otzaria/text_book/view/combined_view/combined_book_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../test_helpers/memory_cache_provider.dart';

// issue #1973 — ספר במצב "טקסט רציף" שנפתח מתוצאת חיפוש נוחת במקום אחר.
//
// הספר נטען בחלקים: בפתיחה נטען חלון סביב השורה שנמצאה, והשאר נטען ברקע.
// במצב רציף כל חלק שנטען *לפני* החלון נכנס לרשימה כפסקאות חדשות, ומספרי
// הסגמנטים של כל מה שאחריו זזים. הרשימה מעוגנת לפי מספר פריט, ולכן המשיכה
// להציג את אותו מספר — שהפך לפסקה מוקדמת בספר.

const int _chapters = 30;
const int _versesPerChapter = 10;
final List<String> _content = [
  for (var chapter = 1; chapter <= _chapters; chapter++) ...[
    '<h2>פרק $chapter</h2>',
    for (var verse = 1; verse <= _versesPerChapter; verse++)
      'פסוק $verse בפרק $chapter: דברי הברית אשר צוה לכרת את בני ישראל '
          'בארץ מואב מלבד הברית אשר כרת אתם בחרב',
  ],
];
const int _targetLine = 20 * (_versesPerChapter + 1) + 5; // פרק 21

TextBookLoaded _state(List<bool> loaded, {String searchText = ''}) {
  final content = [
    for (var i = 0; i < _content.length; i++) loaded[i] ? _content[i] : '',
  ];
  return TextBookLoaded(
    book: TextBook(title: 'ספר בדיקה'),
    showLeftPane: false,
    content: content,
    contentVersion: loaded.where((f) => f).length,
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
    visibleIndices: const [_targetLine],
    pinLeftPane: false,
    searchText: searchText,
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
    supportsContinuousReadingMode: true,
    continuousReadingMode: true,
    readingSegments: buildReadingSegments(
      content,
      continuous: true,
      loadedLineFlags: loaded,
    ),
  );
}

List<bool> _window(int start, int end) => [
  for (var i = 0; i < _content.length; i++) i >= start && i <= end,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  group('reflowAnchor', () {
    // שלושה פרקים; בהתחלה הראשון לא טעון (סגמנט אחד), ואז נטען (שני סגמנטים).
    final partialFlags = [
      for (var i = 0; i < 33; i++) i >= 11,
    ];
    final partial = buildReadingSegments(
      [for (var i = 0; i < 33; i++) partialFlags[i] ? _content[i] : ''],
      continuous: true,
      loadedLineFlags: partialFlags,
    );
    final full = buildReadingSegments(
      _content.sublist(0, 33),
      continuous: true,
    );

    test('פריט שמספרו זז מעוגן במספרו החדש ובאותו גובה', () {
      // partial: [לא-טעון 0..10, כותרת 11, פסקה 12..21, כותרת 22, פסקה 23..32]
      // full:    [כותרת 0, פסקה 1..10, כותרת 11, פסקה 12..21, ...]
      final anchor = reflowAnchor(
        positions: const [
          ItemPosition(index: 2, itemLeadingEdge: -0.4, itemTrailingEdge: 0.3),
          ItemPosition(index: 3, itemLeadingEdge: 0.3, itemTrailingEdge: 0.4),
          ItemPosition(index: 4, itemLeadingEdge: 0.4, itemTrailingEdge: 1.2),
        ],
        previous: partial,
        current: full,
      );
      expect(anchor, (index: 3, alignment: -0.4));
    });

    test('מספור שלא זז — אין עיגון', () {
      final anchor = reflowAnchor(
        positions: const [
          ItemPosition(index: 3, itemLeadingEdge: 0.0, itemTrailingEdge: 0.9),
        ],
        previous: full,
        current: full,
      );
      expect(anchor, isNull);
    });

    test('פריטים מחוץ לתצוגה אינם נבחרים כעוגן', () {
      final anchor = reflowAnchor(
        positions: const [
          ItemPosition(index: 1, itemLeadingEdge: -2, itemTrailingEdge: -0.5),
          ItemPosition(index: 3, itemLeadingEdge: 0.1, itemTrailingEdge: 0.9),
        ],
        previous: partial,
        current: full,
      );
      expect(anchor, (index: 4, alignment: 0.1));
    });
  });

  testWidgets('טעינת רקע של תחילת הספר אינה מזיזה את מקום הקריאה', (
    tester,
  ) async {
    final book = TextBook(title: 'ספר בדיקה');
    final partial = _state(
      _window(_targetLine - 30, _targetLine + 60),
      searchText: 'בחרב',
    );
    final textBookBloc = _TestTextBookBloc(partial);
    final personalNotesBloc = _TestPersonalNotesBloc(
      const PersonalNotesState.initial(),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());
    final tab = TextBookTab(book: book, index: _targetLine);
    addTearDown(textBookBloc.close);
    addTearDown(personalNotesBloc.close);
    addTearDown(settingsBloc.close);
    addTearDown(tab.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TextBookBloc>.value(value: textBookBloc),
            BlocProvider<PersonalNotesBloc>.value(value: personalNotesBloc),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
          ],
          child: Scaffold(
            body: CombinedView(
              data: partial.content,
              openBookCallback: (_) {},
              openLeftPaneTab: (_, {searchText}) {},
              textSize: 18,
              showCommentaryAsExpansionTiles: true,
              tab: tab,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('פסוק 5 בפרק 21'), findsOneWidget);

    // העדכון הראשון שהתצוגה רואה הוא השורות הגלויות, כמו ב-bloc האמיתי.
    textBookBloc.emitForTest(
      partial.copyWith(visibleIndices: [tab.index, tab.index + 1]),
    );
    await tester.pumpAndSettle();
    final placeBeforeWarming = tab.index;
    expect(placeBeforeWarming, inInclusiveRange(_targetLine - 20, _targetLine));

    // חימום הרקע טוען את כל מה שלפני החלון — עשרות פסקאות נכנסות לפני
    // המקום הנוכחי ומספרי הסגמנטים זזים.
    final warmed = _state(_window(0, _targetLine + 60), searchText: 'בחרב');
    textBookBloc.emitForTest(
      warmed.copyWith(visibleIndices: [tab.index, tab.index + 1]),
    );
    await tester.pumpAndSettle();
    expect(
      tab.index,
      placeBeforeWarming,
      reason: 'issue #1973: הרשימה קפצה למקום אחר אחרי טעינת תחילת הספר',
    );
    expect(find.textContaining('פסוק 5 בפרק 21'), findsOneWidget);

    // השלמת הטעינה אחרי החלון אינה נוגעת במספור שלפניו.
    final full = _state(_window(0, _content.length - 1), searchText: 'בחרב');
    textBookBloc.emitForTest(
      full.copyWith(visibleIndices: [tab.index, tab.index + 1]),
    );
    await tester.pumpAndSettle();
    expect(tab.index, placeBeforeWarming);
  });
}

class _TestTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TestTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }
  void emitForTest(TextBookState state) => emit(state);
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
