import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/split_archive_joiner.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  const name = 'seforim.db.zst';
  final whole = List<int>.generate(70, (i) => (i * 13) % 256);
  final parts = [
    whole.sublist(0, 32),
    whole.sublist(32, 64),
    whole.sublist(64),
  ];

  String manifestPath() => p.join(dir.path, '$name.manifest.json');
  String outputPath() => p.join(dir.path, 'joined.zst');

  void writeManifest({String? wholeSha}) {
    File(manifestPath()).writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'archive': name,
        'size': whole.length,
        'sha256': wholeSha ?? sha256.convert(whole).toString(),
        'parts': [
          for (var i = 0; i < parts.length; i++)
            {
              'name': '$name.part-00$i',
              'size': parts[i].length,
              'sha256': sha256.convert(parts[i]).toString(),
            },
        ],
      }),
    );
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('split_joiner_test');
    for (var i = 0; i < parts.length; i++) {
      File(p.join(dir.path, '$name.part-00$i')).writeAsBytesSync(parts[i]);
    }
    writeManifest();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('מחבר לפי הסדר ומדווח התקדמות עד הסוף', () async {
    final progress = <double>[];
    await joinSplitArchive(
      manifestPath(),
      outputPath(),
      onProgress: progress.add,
    );
    expect(File(outputPath()).readAsBytesSync(), whole);
    expect(progress.last, 1.0);
    // החלקים אינם נמחקים: התיקייה של המשתמש נשארת כפי שהייתה.
    expect(File(p.join(dir.path, '$name.part-001')).existsSync(), isTrue);
  });

  test('חלק פגום → נכשל והפלט נמחק', () async {
    File(
      p.join(dir.path, '$name.part-001'),
    ).writeAsBytesSync(List<int>.filled(32, 0));
    await expectLater(
      joinSplitArchive(manifestPath(), outputPath()),
      throwsA(isA<FormatException>()),
    );
    expect(File(outputPath()).existsSync(), isFalse);
  });

  test('חלק חסר → נכשל לפני כתיבה', () async {
    File(p.join(dir.path, '$name.part-002')).deleteSync();
    await expectLater(
      joinSplitArchive(manifestPath(), outputPath()),
      throwsA(isA<FormatException>()),
    );
    expect(File(outputPath()).existsSync(), isFalse);
  });

  test('sha256 של השלם שגוי → נכשל והפלט נמחק', () async {
    writeManifest(wholeSha: 'f' * 64);
    await expectLater(
      joinSplitArchive(manifestPath(), outputPath()),
      throwsA(isA<FormatException>()),
    );
    expect(File(outputPath()).existsSync(), isFalse);
  });
}
