import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/book_composite_key.dart';
import 'package:otzaria/data/data_providers/library_provider.dart';
import 'package:otzaria/data/data_providers/library_provider_manager.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/pdf_book/view/pdf_commentary_panel.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/services/commentary_service.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';

import '../helpers/memory_settings_cache.dart';
import '../support/search_engine_test_init.dart';

// כותרות ייחודיות: מטמון התוכן של Link סטטי ומשותף לכל הבדיקות.
const _commentatorPrefix = 'מפרש חיפוש PDF 1505';
const _groupCount = 40;

// ריפוד באפסים: מיון הקישורים לפי כותרת שווה למיון המספרי.
String _title(int i) => '$_commentatorPrefix ${i.toString().padLeft(2, "0")}';

Future<void> main() async {
  final engineReady = await tryInitSearchEngine();

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  setUp(() {
    final provider = _FakeLibraryProvider();
    LibraryProviderManager.instance.resetForTesting();
    LibraryProviderManager.instance.seedMappingsForTesting(
      mapping: {
        for (var i = 1; i <= _groupCount; i++)
          BookCompositeKey.create(
            title: _title(i),
            categoryId: 1,
            fileType: 'txt',
          ): provider,
      },
      providers: [provider],
    );
  });

  tearDown(LibraryProviderManager.instance.resetForTesting);

  group('חיפוש בחלונית המפרשים של PDF (issue #1505)', () {
    testWidgets('ניווט לתוצאה רחוקה אינו מפיל את הרשימה', (tester) async {
      final tab = _tab();
      addTearDown(tab.dispose);

      await tester.pumpWidget(
        _wrap(
          PdfCommentaryPanel(
            tab: tab,
            linksCount: tab.links.length,
            openBookCallback: (_) {},
            fontSize: 16,
            commentaryGroupsLoader: (links) async => [
              for (final link in links)
                LinkGroup(
                  bookTitle: link.path2.replaceAll('.txt', ''),
                  links: [link],
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(FluentIcons.search_24_regular).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'עמק');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // התוצאה ה-30 נמצאת בקבוצה רחוקה מהמסך שעוד לא נבנתה.
      final next = find.byIcon(FluentIcons.chevron_down_24_regular);
      for (var i = 0; i < 29; i++) {
        await tester.tap(next);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('30/'), findsOneWidget);
      expect(
        find.text(_title(30)).hitTestable(),
        findsWidgets,
        reason: 'הגלילה העדינה צריכה להביא את המפרש של התוצאה לתצוגה',
      );
    }, skip: !engineReady);
  });
}

PdfBookTab _tab() {
  final tab = PdfBookTab(
    book: PdfBook(title: 'ספר בדיקה', path: '/books/ספר בדיקה.pdf'),
    pageNumber: 1,
  );
  tab.currentTextLineNumber = 10;
  tab.currentTextLineNumberEnd = 40;
  tab.links = [
    for (var i = 1; i <= _groupCount; i++)
      Link(
        heRef: _title(i),
        index1: 12,
        path2: '${_title(i)}.txt',
        index2: 1,
        connectionType: 'COMMENTARY',
        targetCategoryId: 1,
        targetFileType: 'txt',
      ),
  ];
  tab.activeCommentators = {
    for (var i = 1; i <= _groupCount; i++) _title(i),
  };
  return tab;
}

Widget _wrap(Widget child) => MaterialApp(
  home: MultiBlocProvider(
    providers: [
      BlocProvider<SettingsBloc>.value(value: _FakeSettingsBloc()),
      BlocProvider<PersonalNotesBloc>.value(value: _FakePersonalNotesBloc()),
    ],
    child: Scaffold(body: child),
  ),
);

class _FakeSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _FakeSettingsBloc() : super(SettingsState.initial()) {
    on<SettingsEvent>((_, _) {});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePersonalNotesBloc
    extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _FakePersonalNotesBloc()
    : super(
        const PersonalNotesState(
          isLoading: false,
          bookId: '',
          locatedNotes: [],
          missingNotes: [],
          errorMessage: null,
          filteredLocatedNotes: [],
          filteredMissingNotes: [],
        ),
      ) {
    on<PersonalNotesEvent>((_, _) {});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeLibraryProvider implements LibraryProvider {
  @override
  String get displayName => 'Fake';

  @override
  bool get isInitialized => true;

  @override
  int get priority => 0;

  @override
  String get providerId => 'fake';

  @override
  String get sourceIndicator => 'T';

  @override
  Future<Library> buildLibraryCatalog(
    Map<String, Map<String, dynamic>> metadata,
    String rootPath,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Link>> getAllLinksForBook(
    String title,
    int categoryId,
    String fileType,
  ) async => const [];

  @override
  Future<Set<String>> getAvailableBookTitles() async => const {};

  @override
  Future<String?> getBookText(
    String title,
    int categoryId,
    String fileType, {
    BookSource preferSource = BookSource.official,
  }) async => null;

  @override
  Future<List<TocEntry>?> getBookToc(
    String title,
    int categoryId,
    String fileType, {
    BookSource preferSource = BookSource.official,
  }) async => const [];

  @override
  Future<String> getLinkContent(Link link) async =>
      'דְּבֵין עָמֹק בֵּין דֵּהֶה טָהוֹר.';

  @override
  Future<bool> hasBook(String title, int categoryId, String fileType) async =>
      title.startsWith(_commentatorPrefix);

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, List<Book>>> loadBooks(
    Map<String, Map<String, dynamic>> metadata,
  ) async => const {};
}
