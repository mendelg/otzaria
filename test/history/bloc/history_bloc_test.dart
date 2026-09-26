import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/history/bloc/history_state.dart';
import 'package:otzaria/history/history_repository.dart';
import 'package:otzaria/models/books.dart';

class _BlockingHistoryRepository extends HistoryRepository {
  final loadStarted = Completer<void>();
  final releaseLoad = Completer<List<Bookmark>>();
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  int saveCount = 0;

  @override
  Future<List<Bookmark>> load() {
    loadStarted.complete();
    return releaseLoad.future;
  }

  /// מה ש"על הדיסק". [mutate] האמיתי קורא אותו מחדש לפני כל החלה, וזה מה
  /// שהופך שתי כתיבות רצופות לצטברות במקום לדרוס.
  List<Bookmark> stored = [];

  @override
  Future<List<Bookmark>> mutate(
    List<Bookmark> Function(List<Bookmark> current) apply,
  ) async {
    saveCount++;
    if (saveCount == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    stored = List<Bookmark>.from(apply(List<Bookmark>.from(stored)));
    return List<Bookmark>.from(stored);
  }
}

class _MemoryHistoryRepository extends HistoryRepository {
  List<Bookmark> stored = [];

  @override
  Future<List<Bookmark>> load() async => stored;

  @override
  Future<List<Bookmark>> mutate(
    List<Bookmark> Function(List<Bookmark> current) apply,
  ) async {
    stored = List<Bookmark>.from(apply(List<Bookmark>.from(stored)));
    return List<Bookmark>.from(stored);
  }
}

Bookmark _bookmark(String title) => Bookmark(
  ref: title,
  book: TextBook(title: title),
  index: 0,
);

void main() {
  test('כתיבות היסטוריה רצופות נשמרות בלי לדרוס זו את זו', () async {
    final repository = _BlockingHistoryRepository();
    final bloc = HistoryBloc(repository);
    addTearDown(bloc.close);

    await repository.loadStarted.future;
    final loaded = bloc.stream.firstWhere((state) => state is HistoryLoaded);
    repository.releaseLoad.complete([]);
    await loaded;

    final first = _bookmark('ספר א');
    final second = _bookmark('ספר ב');
    bloc.add(BulkAddHistory([first]));
    await repository.firstSaveStarted.future;

    bloc.add(BulkAddHistory([second]));
    await Future<void>.delayed(Duration.zero);
    expect(repository.saveCount, 1);

    repository.releaseFirstSave.complete();
    await bloc.stream.firstWhere((state) => state.history.length == 2);

    expect(bloc.state.history.map((bookmark) => bookmark.book.title), [
      'ספר ב',
      'ספר א',
    ]);
  });

  group('רשומת היסטוריה לפי זהות הספר ולא לפי כותרת', () {
    Future<HistoryBloc> loadedBloc() async {
      final bloc = HistoryBloc(_MemoryHistoryRepository());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((state) => state is HistoryLoaded);
      return bloc;
    }

    Future<List<Bookmark>> addAll(
      HistoryBloc bloc,
      List<Bookmark> entries,
    ) async {
      for (final entry in entries) {
        bloc.add(BulkAddHistory([entry]));
        await bloc.stream.firstWhere(
          (state) => identical(state.history.firstOrNull, entry),
        );
      }
      return bloc.state.history;
    }

    test('פתיחת ה-PDF של מסכת אינה מוחקת את מיקום הקריאה בטקסט', () async {
      final bloc = await loadedBloc();
      final text = Bookmark(
        ref: 'ברכות ה א',
        book: TextBook(id: 103, title: 'ברכות', categoryId: 3),
        index: 120,
      );
      final pdf = Bookmark(
        ref: 'ברכות עמוד 16',
        book: PdfBook(
          id: 103,
          title: 'ברכות',
          path: '/books/תלמוד בבלי/ברכות.pdf',
          categoryId: 3,
        ),
        index: 16,
      );

      final history = await addAll(bloc, [text, pdf]);

      expect(history, [pdf, text]);
    });

    test('שני קובצי PDF שונים באותה כותרת נשמרים בנפרד', () async {
      final bloc = await loadedBloc();
      Bookmark pdfAt(String path, int page) => Bookmark(
        ref: 'ברכות עמוד $page',
        book: PdfBook(title: 'ברכות', path: path),
        index: page,
      );
      final first = pdfAt('/books/א/ברכות.pdf', 7);
      final second = pdfAt('/books/ב/ברכות.pdf', 30);

      final history = await addAll(bloc, [first, second]);

      expect(history, [second, first]);
    });

    test('ביקור חוזר באותו ספר מחליף את הרשומה הקודמת שלו', () async {
      final bloc = await loadedBloc();
      Bookmark textAt(int index) => Bookmark(
        ref: 'ברכות $index',
        book: TextBook(id: 103, title: 'ברכות', categoryId: 3),
        index: index,
      );
      final older = textAt(5);
      final newer = textAt(40);

      final history = await addAll(bloc, [older, newer]);

      expect(history, [newer]);
    });
  });
}
