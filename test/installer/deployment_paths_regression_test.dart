import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String routine(String script, String signature) {
  final start = script.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: signature);
  return script.substring(start, script.indexOf('\nend;', start) + 5);
}

void main() {
  final script = File('installer/otzaria.iss').readAsStringSync();
  test('missing part000 cannot bypass library or index validation', () {
    final probe = routine(script, 'function HasSplitArchiveParts(');
    expect(probe, contains("ArchiveName + '.part-*'"));
    final prepare = routine(script, 'function PrepareLibraryParts(');
    expect(
      prepare,
      contains("HasSplitArchiveParts(SourceDir, '{#LibraryArchiveName}')"),
    );
    expect(
      prepare,
      contains("HasSplitArchiveParts(SourceDir, '{#IndexArchiveName}')"),
    );
    expect(prepare, isNot(contains('.part-000')));
    expect(prepare, contains("PrepareSplitArchive('library.manifest.json'"));
    expect(
      prepare,
      contains("PrepareSplitArchive('library_index.manifest.json'"),
    );
  });
  test(
    'legacy root-only records resolve a unique nested DB or stop on ambiguity',
    () {
      final resolve = routine(
        script,
        'function GetLibraryBooksPath(): String;\nvar',
      );
      expect(resolve, contains('FindFirst(AddBackslash(CustomPath)'));
      expect(resolve, contains("FindRec.Name + '\\seforim.db'"));
      expect(resolve, contains('CandidateCount = 1'));
      expect(resolve, contains('CandidateCount > 1'));
      expect(resolve, contains("Result := '';"));
      final next = routine(script, 'function NextButtonClick(');
      expect(next, contains("GetLibraryBooksPath() = ''"));
      expect(next, contains('Result := False;'));
    },
  );
  test(
    'stale DB records cannot bypass discovery of the existing nested DB',
    () {
      final resolve = routine(
        script,
        'function GetLibraryBooksPath(): String;\nvar',
      );
      final recordCheck = resolve.indexOf(
        "if FileExists(AddBackslash(DatabasePath) + 'seforim.db')",
      );
      expect(recordCheck, greaterThan(0));
      expect(recordCheck, lessThan(resolve.indexOf('Result := DatabasePath')));
      expect(resolve, contains("ReadLibraryPathRecord(GetDataDir(''))"));
      expect(resolve, contains("AddBackslash(GetDataDir(''))"));
      expect(
        routine(script, 'function NextButtonClick('),
        contains('עדכנו תחילה את התוכנה בלבד'),
      );
    },
  );
  test(
    'nested DB keeps app index adjacent to configured root, semantic beside DB',
    () {
      final index = routine(script, 'function GetLibraryIndexPath(');
      expect(index, contains('ExtractFileDir(CustomPath)'));
      final extract = routine(script, 'procedure ExtractLibraryArchives(');
      expect(
        extract,
        contains('TargetIndex := GetLibraryIndexPath(BooksPath)'),
      );
      expect(extract, contains('IndexBackup := TargetIndex'));
      expect(
        extract,
        contains('IndexStagingRoot := ExtractFileDir(TargetIndex)'),
      );
      expect(
        extract,
        contains('UnpackArchive(PreparedIndexArchive, IndexStagingRoot,'),
      );
      expect(
        routine(script, 'function GetSemanticImportDir('),
        contains('ExtractFileDir(GetLibraryBooksPath())'),
      );
    },
  );
}
