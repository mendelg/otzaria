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
import 'package:otzaria/widgets/commentary/commentary_content.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/services/commentary_service.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';

import '../helpers/memory_settings_cache.dart';

// כותרות ייחודיות: מטמון התוכן של Link סטטי ומשותף לכל הבדיקות.
const _commentatorPrefix = 'מפרש רשימה עצלה PDF';
const _groupCount = 1;

// ריפוד באפסים: מיון הקישורים לפי כותרת שווה למיון המספרי.
String _title(int i) => '$_commentatorPrefix ${i.toString().padLeft(2, "0")}';

void main() {
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

  group('רשימת המפרשים של PDF בונה רק את מה שעל המסך (#844)', () {
    testWidgets('קבוצה גדולה ופתוחה אינה בונה את כל הקטעים', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tab = _bigGroupTab(300);
      addTearDown(tab.dispose);
      await tester.pumpWidget(_wrap(_panel(tab)));
      await tester.pumpAndSettle();

      final built = find
          .byType(CommentaryContent, skipOffstage: false)
          .evaluate()
          .length;
      expect(built, greaterThan(0));
      expect(built, lessThan(40));
    });
  });
}

PdfCommentaryPanel _panel(PdfBookTab tab) => PdfCommentaryPanel(
  tab: tab,
  linksCount: tab.links.length,
  openBookCallback: (_) {},
  fontSize: 16,
  commentaryGroupsLoader: (links) async => [
    LinkGroup(bookTitle: _title(1), links: links),
  ],
);

/// One commentator with [count] commentaries on the shown range.
PdfBookTab _bigGroupTab(int count) {
  final tab = PdfBookTab(
    book: PdfBook(title: 'ספר בדיקה', path: '/books/ספר בדיקה.pdf'),
    pageNumber: 1,
  );
  tab.currentTextLineNumber = 10;
  tab.currentTextLineNumberEnd = 40;
  tab.links = [
    for (var i = 1; i <= count; i++)
      Link(
        heRef: _title(1),
        index1: 12,
        path2: '${_title(1)}.txt',
        index2: i,
        connectionType: 'COMMENTARY',
        targetCategoryId: 1,
        targetFileType: 'txt',
      ),
  ];
  tab.activeCommentators = {_title(1)};
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
