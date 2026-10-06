import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_event.dart';
import 'package:otzaria/library/hidden/hidden_library_selection.dart';
import 'package:otzaria/library/hidden/hidden_library_store.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/models/books.dart';

import '../../helpers/memory_settings_cache.dart';

class _Files extends Fake implements FileSystemData {
  _Files(this.next);

  final Library next;

  @override
  String libraryPath = '.';

  @override
  Future<Library> getLibrary() async => next;
}

class _ReadyIndex extends Fake implements TantivyDataProvider {
  @override
  Future<bool> reopenIndex({bool force = false}) async => true;
}

class _EmptyHiddenStore extends HiddenLibraryStore {
  const _EmptyHiddenStore();

  @override
  HiddenLibrarySelection load() => const HiddenLibrarySelection();
}

/// בונה ספרייה שבה כל ספר יושב בשרשרת הקטגוריות שלו.
Library _libraryOf(Map<List<String>, List<Book Function(Category)>> tree) {
  final library = Library(categories: []);
  for (final entry in tree.entries) {
    Category parent = library;
    for (final title in entry.key) {
      final child = Category(
        title: title,
        description: '',
        shortDescription: '',
        order: 0,
        subCategories: [],
        books: [],
        parent: parent,
      );
      parent.subCategories.add(child);
      parent = child;
    }
    for (final build in entry.value) {
      parent.books.add(build(parent));
    }
  }
  return library;
}

TextBook _userBook(Category category) => TextBook(
  id: 5,
  title: 'אנציקלופדיה תלמודית אות מ',
  source: BookSource.user,
  category: category,
);

TextBook _officialBook(Category category) =>
    TextBook(id: 9, title: 'משנה ברורה', category: category);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileSystemData previousFiles;
  late TantivyDataProvider previousIndex;

  setUp(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
    previousFiles = FileSystemData.instance;
    previousIndex = TantivyDataProvider.instance;
    TantivyDataProvider.instance = _ReadyIndex();
  });

  tearDown(() {
    FileSystemData.instance = previousFiles;
    TantivyDataProvider.instance = previousIndex;
  });

  Future<List<Book>?> refreshBetween(Library before, Library after) async {
    final files = _Files(after);
    FileSystemData.instance = files;
    final repository = DataRepository(fileSystemData: files);
    repository.library = Future.value(before);
    await repository.library;
    final bloc = LibraryBloc(
      hiddenStore: const _EmptyHiddenStore(),
      repository: repository,
    );
    addTearDown(bloc.close);
    final done = bloc.stream.firstWhere(
      (state) => state.completedRefreshRequestIds?.contains(1) ?? false,
    );
    bloc.add(const RefreshLibrary(requestIds: {1}));
    return (await done).changedBooksToIndex;
  }

  group('רענון שמעביר ספר לקטגוריה אחרת (issue #1977)', () {
    test(
      'מיזוג ספרים אישיים לעץ — הספר שעבר מאונדקס מחדש (issue #1977)',
      () async {
        final before = _libraryOf({
          ['ספרים אישיים', 'ספריה', 'מילונים וספרי יעץ', 'אנציקלופדיות']: [
            _userBook,
          ],
          ['הלכה']: [_officialBook],
        });
        final after = _libraryOf({
          ['מילונים וספרי יעץ', 'אנציקלופדיות']: [_userBook],
          ['הלכה']: [_officialBook],
        });

        final changed = await refreshBetween(before, after);

        expect(changed?.map((b) => b.title), ['אנציקלופדיה תלמודית אות מ']);
        expect(
          changed!.single.category!.path,
          '/מילונים וספרי יעץ/אנציקלופדיות',
        );
      },
    );

    test('רענון שלא הזיז ספרים — אין אינדוקס מחדש (issue #1977)', () async {
      Library build() => _libraryOf({
        ['מילונים וספרי יעץ', 'אנציקלופדיות']: [_userBook],
        ['הלכה']: [_officialBook],
      });

      expect(await refreshBetween(build(), build()), isNull);
    });
  });
}
