import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_event.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/library_update/bloc/library_update_bloc.dart';
import 'package:otzaria/library/view/grid_items.dart';
import 'package:otzaria/library/view/library_browser.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tools/calendar/bloc/calendar_cubit.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/memory_cache_provider.dart';

class _MockLibraryBloc extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockNavigationBloc extends MockBloc<NavigationEvent, NavigationState>
    implements NavigationBloc {}

class _MockLibraryUpdateBloc
    extends MockBloc<LibraryUpdateEvent, LibraryUpdateState>
    implements LibraryUpdateBloc {}

/// מספק CalendarState קבוע בלי להריץ את אתחול ה-cubit האמיתי.
class _StubCalendarCubit extends Cubit<CalendarState> implements CalendarCubit {
  _StubCalendarCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Category _category(String title, Category parent) {
  final category = Category(
    title: title,
    description: '',
    shortDescription: '',
    order: 0,
    subCategories: [],
    books: [],
    parent: parent,
  );
  parent.subCategories.add(category);
  return category;
}

Future<void> _pumpLibraryBrowser(
  WidgetTester tester,
  LibraryState state, {
  required Size size,
}) async {
  final libraryBloc = _MockLibraryBloc();
  final settingsBloc = _MockSettingsBloc();
  final navigationBloc = _MockNavigationBloc();
  final libraryUpdateBloc = _MockLibraryUpdateBloc();
  final calendarCubit = _StubCalendarCubit(CalendarState.initial());

  whenListen(
    libraryBloc,
    const Stream<LibraryState>.empty(),
    initialState: state,
  );
  whenListen(
    settingsBloc,
    const Stream<SettingsState>.empty(),
    initialState: SettingsState.initial(),
  );
  whenListen(
    navigationBloc,
    const Stream<NavigationState>.empty(),
    initialState: const NavigationState(currentScreen: Screen.library),
  );
  whenListen(
    libraryUpdateBloc,
    const Stream<LibraryUpdateState>.empty(),
    initialState: const LibraryUpdateState(),
  );

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.reset();
    await libraryBloc.close();
    await settingsBloc.close();
    await navigationBloc.close();
    await libraryUpdateBloc.close();
    await calendarCubit.close();
  });

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('he', 'IL'),
      home: MultiProvider(
        providers: [
          Provider<FocusRepository>.value(value: FocusRepository()),
          BlocProvider<LibraryBloc>.value(value: libraryBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<NavigationBloc>.value(value: navigationBloc),
          BlocProvider<LibraryUpdateBloc>.value(value: libraryUpdateBloc),
          BlocProvider<CalendarCubit>.value(value: calendarCubit),
        ],
        child: const LibraryBrowser(),
      ),
    ),
  );
  await tester.pump();
  // כפתור הדף היומי גולש עם CalendarState מדומה — לא נושא הבדיקה.
  tester.takeException();
}

void main() {
  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  testWidgets('רשת תוצאות החיפוש במסך צר אינה מייצרת כרטיסים גבוהים', (
    tester,
  ) async {
    final library = Library(categories: []);
    await _pumpLibraryBrowser(
      tester,
      LibraryState(
        library: library,
        currentCategory: library,
        searchResults: [
          TextBook(title: 'משנה ברורה', author: 'החפץ חיים'),
          TextBook(title: 'שולחן ערוך', author: 'מרן הבית יוסף'),
        ],
        searchQuery: 'ברורה',
      ),
      size: const Size(411, 731),
    );

    expect(find.byType(BookGridItem), findsWidgets);
    expect(
      tester.getSize(find.byType(BookGridItem).first).height,
      lessThanOrEqualTo(130),
    );
  });

  testWidgets(
    'תיקיות באותו שם בתוצאות החיפוש ברשת מציגות את נתיב האב (issue #1718)',
    (tester) async {
      final library = Library(categories: []);
      final shasCommentaries = _category(
        'מפרשים',
        _category('תלמוד בבלי', library),
      );
      final shulchanAruchCommentaries = _category(
        'מפרשים',
        _category('שולחן ערוך', _category('הלכה', library)),
      );
      await _pumpLibraryBrowser(
        tester,
        LibraryState(
          library: library,
          currentCategory: library,
          searchResults: const [],
          searchCategoryResults: [
            _category('בית מאיר', shasCommentaries),
            _category('בית מאיר', shulchanAruchCommentaries),
          ],
          searchQuery: 'בית מאיר',
        ),
        size: const Size(1200, 800),
      );

      final cards = find.byType(CategoryGridItem);
      expect(cards, findsNWidgets(2));
      Finder inCard(int index, String text) =>
          find.descendant(of: cards.at(index), matching: find.text(text));
      expect(inCard(0, 'תלמוד בבלי, מפרשים'), findsOneWidget);
      expect(inCard(1, 'הלכה, שולחן ערוך, מפרשים'), findsOneWidget);
    },
  );
}
