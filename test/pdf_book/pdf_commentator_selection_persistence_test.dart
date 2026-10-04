import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/pdf_book/view/pdf_book_screen.dart';
import 'package:otzaria/settings/services/per_book_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dataRoot;
  final book = PdfBook(title: 'בדיקת מפרשים', path: '/commentators.pdf');

  setUp(() async {
    dataRoot = await Directory.systemTemp.createTemp('pdf_commentators_');
    AppPaths.debugOverrideDataRootPath(dataRoot.path);
  });

  tearDown(() async {
    await PerBookSettings.settle();
    AppPaths.debugOverrideDataRootPath(null);
    await dataRoot.delete(recursive: true);
  });

  for (final initial in [
    {'רש"י'},
    {'רש"י', 'רמב"ן'},
  ]) {
    test('לחיצות חוזרות על מפרש פעיל פותחות בלי לשמור $initial', () async {
      final active = Set<String>.of(initial);
      await PdfBookPerBookSettings(
        activeCommentators: active.toList(),
        zoom: 2,
      ).save(book);
      final file = (await Directory(
        '${dataRoot.path}/per_book_settings',
      ).list().toList()).whereType<File>().single;
      final original = await file.readAsString();
      await file.setLastModified(DateTime.utc(2000));
      final modified = await file.lastModified();
      var saves = 0;
      var opens = 0;
      final entries = buildGroupedCommentatorEntries(
        relevantCommentators: const ['רש"י', 'רמב"ן'],
        commentatorGroups: const [],
        activeCommentators: active,
        onCommentatorsChanged: (updated) => applyPdfCommentatorSelection(
          activeCommentators: active,
          updated: updated,
          onChanged: () {
            saves++;
            unawaited(
              PdfBookPerBookSettings(
                activeCommentators: active.toList(),
              ).save(book),
            );
          },
          onOpenPane: () => opens++,
        ),
        onToggleAll: (_) {},
      );
      final entry = entries.firstWhere((entry) => entry.label == 'רש"י');

      for (var i = 0; i < 3; i++) {
        entry.onTap!();
        await PerBookSettings.settle();
        expect(await file.readAsString(), original);
        expect(await file.lastModified(), modified);
      }
      expect(saves, 0);
      expect(opens, 3);
      expect(active, initial);
    });
  }

  test('בחירה חדשה נשמרת פעם אחת ונפתחת גם בלחיצה חוזרת', () async {
    final active = {'רמב"ן'};
    var saves = 0;
    var opens = 0;
    final entries = buildGroupedCommentatorEntries(
      relevantCommentators: const ['רש"י', 'רמב"ן'],
      commentatorGroups: const [],
      activeCommentators: active,
      onCommentatorsChanged: (updated) => applyPdfCommentatorSelection(
        activeCommentators: active,
        updated: updated,
        onChanged: () {
          saves++;
          unawaited(
            PdfBookPerBookSettings(
              activeCommentators: active.toList(),
            ).save(book),
          );
        },
        onOpenPane: () => opens++,
      ),
      onToggleAll: (_) {},
    );
    final entry = entries.firstWhere((entry) => entry.label == 'רש"י');
    entry.onTap!();
    await PerBookSettings.settle();
    expect(
      (await PdfBookPerBookSettings.load(book))?.activeCommentators,
      unorderedEquals(['רמב"ן', 'רש"י']),
    );
    entry.onTap!();
    await PerBookSettings.settle();
    expect(saves, 1);
    expect(opens, 2);
    expect(active, {'רמב"ן', 'רש"י'});
  });

  test('השוואת בחירה אינה תלויה בסדר הקבוצה', () {
    var saves = 0;
    var opens = 0;
    final active = {'רש"י', 'רמב"ן'};
    applyPdfCommentatorSelection(
      activeCommentators: active,
      updated: {'רמב"ן', 'רש"י'},
      onChanged: () => saves++,
      onOpenPane: () => opens++,
    );
    expect(saves, 0);
    expect(opens, 1);
    expect(active.toList(), ['רש"י', 'רמב"ן']);
  });
}
