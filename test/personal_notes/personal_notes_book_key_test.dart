import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/personal_notes/utils/personal_notes_book_key.dart';

Library _library(List<Book> books) {
  final category = Category(
    title: 'root',
    description: '',
    shortDescription: '',
    order: 0,
    subCategories: [],
    books: books,
    parent: null,
  );
  final library = Library(categories: [category]);
  category.parent = library;
  return library;
}

void main() {
  final attachedSource = BookSource.attached('lib-a');

  test('title key never resolves to an attached book of the same title', () {
    final attached = TextBook(id: 1, title: 'book', source: attachedSource);
    final library = _library([attached]);

    expect(findBookForPersonalNotesKey(library, 'book'), isNull);
    expect(findTextBookForPersonalNotesKey(library, 'book'), isNull);
  });

  test('attached key resolves only the book of that library', () {
    final official = TextBook(id: 1, title: 'book');
    final attached = TextBook(id: 1, title: 'book', source: attachedSource);
    final other = TextBook(
      id: 1,
      title: 'book',
      source: BookSource.attached('lib-b'),
    );
    final library = _library([official, other, attached]);

    expect(
      findBookForPersonalNotesKey(library, personalNotesBookKey(attached)),
      same(attached),
    );
    expect(
      findTextBookForPersonalNotesKey(library, personalNotesBookKey(official)),
      same(official),
    );
  });

  test('attached PDF resolves as a book but not as a text book', () {
    final pdf = PdfBook(
      id: 2,
      title: 'scan',
      path: '/tmp/scan.pdf',
      source: attachedSource,
    );
    final library = _library([pdf]);
    final key = personalNotesBookKey(pdf);

    expect(findBookForPersonalNotesKey(library, key), same(pdf));
    expect(findTextBookForPersonalNotesKey(library, key), isNull);
  });

  test('category keys cover nested books as a set for O(1) lookup', () {
    final attached = TextBook(id: 3, title: 'deep', source: attachedSource);
    final child = Category(
      title: 'child',
      description: '',
      shortDescription: '',
      order: 0,
      subCategories: [],
      books: [
        attached,
        TextBook(id: 4, title: 'shared'),
      ],
      parent: null,
    );
    final root = Category(
      title: 'root',
      description: '',
      shortDescription: '',
      order: 0,
      subCategories: [child],
      books: [
        TextBook(id: 5, title: 'top'),
        PdfBook(title: 'shared', path: '/s.pdf'),
      ],
      parent: null,
    );

    final keys = personalNotesBookKeysInCategory(root);

    expect(keys, isA<Set<String>>());
    expect(keys, {'top', 'shared', personalNotesBookKey(attached)});
  });
}
