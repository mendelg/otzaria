import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/line_content_codec.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../support/zstd_test_lib.dart';

/// מסגרות שנדחסו ב-python-zstandard (zstd 1.5.7, רמה 19) עם המילון שב-fixture —
/// אותם פרמטרים כמו שלב הדחיסה ב-SeforimLibrary.
const _frames = {
  'בראשית ברא אלהים את השמים ואת הארץ':
      'KLUv/SPzm8ALPt0AADjXlJDXqNelB/yVTjhBGEU4SMDKhj3ZIIQ6Aw==',
  '<b>אמר רבי יוחנן</b> משום רבי שמעון':
      'KLUv/SPzm8ALOp0AABg8Yj4E/Ak9kdLO7Q040G5Y2gY=',
  '': 'KLUv/SPzm8ALAAEAAA==',
  'ascii': 'KLUv/SPzm8ALBSkAAGFzY2lp',
};

void main() {
  final lib = openZstdForTests();
  final skip = lib == null ? 'libzstd אינו זמין' : null;
  final dictionary = File(
    'test/fixtures/line_content_codec/dict.zdict',
  ).readAsBytesSync();

  setUpAll(() {
    if (lib != null) LineContentCodec.openLibrary = () => lib;
  });

  sqlite3.Database compressedDb({Uint8List? dict}) {
    final db = sqlite3.sqlite3.openInMemory();
    db.execute('CREATE TABLE zstd_dict (id INTEGER PRIMARY KEY, dict BLOB)');
    db.execute('INSERT INTO zstd_dict VALUES (1, ?)', [dict ?? dictionary]);
    return db;
  }

  test('מסגרות של מימוש אחר מפוענחות לטקסט המקורי', () {
    final db = compressedDb();
    addTearDown(db.close);
    final codec = LineContentCodec.of(db);
    expect(codec.isCompressed, isTrue);
    for (final MapEntry(key: text, value: frame) in _frames.entries) {
      final bytes = base64.decode(frame);
      expect(isZstdFrame(bytes), isTrue);
      expect(codec.text(bytes), text);
      expect(codec.bytes(bytes), utf8.encode(text));
    }
    expect(identical(LineContentCodec.of(db), codec), isTrue);
  }, skip: skip);

  test('מסד בלי zstd_dict: טקסט עובר כמו שהוא, מסגרת נדחית', () {
    final db = sqlite3.sqlite3.openInMemory();
    addTearDown(db.close);
    final codec = LineContentCodec.of(db);
    expect(codec.isCompressed, isFalse);
    expect(codec.text('שורה'), 'שורה');
    expect(codec.text(null), isNull);
    expect(
      () => codec.text(base64.decode(_frames['ascii']!)),
      throwsFormatException,
    );
  });

  test('מסגרת פגומה או של מילון אחר נכשלת בשגיאת פורמט', () {
    final db = compressedDb();
    addTearDown(db.close);
    final codec = LineContentCodec.of(db);
    final frame = base64.decode(_frames['בראשית ברא אלהים את השמים ואת הארץ']!);
    expect(
      () => codec.bytes(Uint8List.sublistView(frame, 0, frame.length - 3)),
      throwsFormatException,
    );
    final otherDict = Uint8List.fromList(frame)..[6] ^= 0xFF;
    expect(() => codec.bytes(otherDict), throwsFormatException);
    expect(
      () => codec.bytes(Uint8List.fromList(utf8.encode('טקסט'))),
      throwsFormatException,
    );
  }, skip: skip);

  test('דחיסה ופענוח הלוך-חזור, כולל שורה ארוכה', () {
    final db = compressedDb();
    addTearDown(db.close);
    final codec = LineContentCodec.of(db);
    final long = 'אמר רבא ' * 20000;
    final frame = compressWithDictionary(
      lib!,
      Uint8List.fromList(utf8.encode(long)),
      dictionary,
    );
    expect(codec.text(frame), long);
    expect(codec.text(base64.decode(_frames['ascii']!)), 'ascii');
  }, skip: skip);
}
