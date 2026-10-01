import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/line_content_codec.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../support/zstd_test_lib.dart';

/// עותק של `zstd/line_content_golden_frames.json` מ-SeforimLibrary: מסגרות
/// ש-zstd-jni (רמה 19) דחס עם המילון האמיתי. ה-CI משווה את העותק למקור בקומיט נעוץ.
const _vectorPath = 'test/fixtures/line_content_codec/sl_golden_frames.json';

void main() {
  final vector =
      jsonDecode(File(_vectorPath).readAsStringSync()) as Map<String, Object?>;
  final dictId = vector['dictId']! as int;
  final frames = [
    for (final entry in vector['frames']! as List)
      (
        text: (entry as Map)['text'] as String,
        frame: base64.decode(entry['frame'] as String),
      ),
  ];
  final lib = openZstdForTests();
  final dictionary = realLineContentDictionary();
  final skip = lib == null
      ? 'libzstd אינו זמין'
      : dictionary == null
      ? 'מילון SeforimLibrary חסר (OTZARIA_LINE_CONTENT_DICT)'
      : null;

  setUpAll(() {
    if (lib != null) LineContentCodec.openLibrary = () => lib;
  });

  LineContentCodec codecWith(Uint8List dict) {
    final db = sqlite3.sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('CREATE TABLE zstd_dict (id INTEGER PRIMARY KEY, dict BLOB)');
    db.execute('INSERT INTO zstd_dict VALUES (?, ?)', [dictId, dict]);
    return LineContentCodec.of(db);
  }

  test('הווקטור הוא המילון והמסגרות שהוקפאו ב-SeforimLibrary', () {
    expect(sha256.convert(dictionary!).toString(), vector['dictSha256']);
    // כותרת מילון zstd: magic 0xEC30A437 ואחריו ה-dictID, little-endian.
    final header = ByteData.sublistView(dictionary, 0, 8);
    expect(header.getUint32(0, Endian.little), 0xEC30A437);
    expect(header.getUint32(4, Endian.little), dictId);
    expect(dictId, 0x8000);
    // מזהה 32768..65535 תופס שדה Dictionary_ID של 2 בתים בכותרת כל מסגרת.
    for (final (:frame, text: _) in frames) {
      expect(frame[4] & 0x03, 2);
      expect(
        ByteData.sublistView(frame, 5, 7).getUint16(0, Endian.little),
        dictId,
      );
    }
    final joined = [for (final f in frames) ...f.frame];
    expect(sha256.convert(joined).toString(), vector['framesSha256']);
    expect(frames, hasLength(5));
  }, skip: skip);

  test('Dart מפענח את מסגרות ה-Kotlin לטקסט המדויק', () {
    final codec = codecWith(dictionary!);
    for (final (:text, :frame) in frames) {
      expect(isZstdFrame(frame), isTrue);
      expect(codec.text(frame), text);
      expect(codec.bytes(frame), utf8.encode(text));
    }
    expect(frames.map((f) => f.text), contains(''));
    expect(frames.map((f) => f.text), contains('ד"ה ' * 500));
  }, skip: skip);

  test('מסגרות המילון האמיתי נדחות מול מילון אחר', () {
    final testDictionary = File(
      'test/fixtures/line_content_codec/dict.zdict',
    ).readAsBytesSync();
    final codec = codecWith(testDictionary);
    expect(() => codec.text(frames.first.frame), throwsFormatException);
  }, skip: lib == null ? 'libzstd אינו זמין' : null);
}
