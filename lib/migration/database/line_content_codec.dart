import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:otzaria/utils/file/zstd_library.dart';
import 'package:zstandard_native/zstandard_native_bindings.dart';

/// מפענח טקסט שורה: במסד עם טבלת `zstd_dict` כל `line_content.content`
/// ו-`version_line.content` שאינו NULL הוא מסגרת zstd של מילון מהטבלה.
/// ערך TEXT (מסד ישן, user_books.db) מוחזר כמו שהוא.
///
/// אחד לכל חיבור ([of]); אינו בטוח לשימוש מכמה isolates.
final class LineContentCodec implements Finalizable {
  LineContentCodec._(this._decoder);

  static final _byDatabase = Expando<LineContentCodec>();

  /// טוען את libzstd; בדיקות מחליפות אותו.
  @visibleForTesting
  static DynamicLibrary Function() openLibrary = openZstandardLib;
  static final _plain = LineContentCodec._(null);

  /// השורה הגדולה בספרייה היום ~1.3MB; מסגרת שמצהירה על יותר — פגומה.
  static const maxLineBytes = 16 * 1024 * 1024;

  final _ZstdDictDecoder? _decoder;

  /// למסד יש `zstd_dict`, כלומר שורותיו (או חלקן) דחוסות.
  bool get isCompressed => _decoder != null;

  /// ה-codec של [db]; המילונים נטענים פעם אחת לכל חיבור.
  static LineContentCodec of(sqlite3.Database db) =>
      _byDatabase[db] ??= _open(db);

  static LineContentCodec _open(sqlite3.Database db) {
    final hasDictionaries = db.select(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'zstd_dict'",
    );
    if (hasDictionaries.isEmpty) return _plain;
    final dictionaries = [
      for (final row in db.select('SELECT dict FROM zstd_dict'))
        switch (row.values.first) {
          final Uint8List dict => dict,
          final other => throw FormatException('zstd_dict מכיל $other'),
        },
    ];
    return LineContentCodec._(_ZstdDictDecoder(dictionaries));
  }

  /// הטקסט של ערך עמודה: null נשאר null.
  String? text(Object? value) => switch (value) {
    null => null,
    final String text => text,
    final Uint8List frame => utf8.decode(bytes(frame)),
    _ => throw FormatException('ערך שורה מסוג ${value.runtimeType}'),
  };

  /// בייטי ה-UTF-8 של [frame].
  Uint8List bytes(Uint8List frame) {
    final decoder = _decoder;
    if (decoder == null) {
      throw const FormatException('שורה דחוסה במסד בלי zstd_dict');
    }
    return decoder.decompress(frame);
  }
}

/// תחילית מסגרת zstd (0xFD2FB528, little-endian). טקסט UTF-8 תקין לעולם
/// לא מתחיל בה: 0xB5 אינו יכול לבוא אחרי תו ASCII.
bool isZstdFrame(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x28 &&
    bytes[1] == 0xB5 &&
    bytes[2] == 0x2F &&
    bytes[3] == 0xFD;

final class _ZstdDictDecoder implements Finalizable {
  _ZstdDictDecoder(List<Uint8List> dictionaries) : _ddicts = {} {
    final lib = LineContentCodec.openLibrary();
    _zstd = ZstandardNativeBindings(lib);
    // NativeFinalizer שאינו נגיש לא מריץ את ה-callbacks שלו — לכן סטטי.
    final freeDDict = _freeDDict ??= NativeFinalizer(
      lib.lookup<NativeFinalizerFunction>('ZSTD_freeDDict'),
    );
    final freeDCtx = _freeDCtx ??= NativeFinalizer(
      lib.lookup<NativeFinalizerFunction>('ZSTD_freeDCtx'),
    );
    for (final dict in dictionaries) {
      final native = malloc<Uint8>(dict.length);
      try {
        native.asTypedList(dict.length).setAll(0, dict);
        final ddict = _zstd.ZSTD_createDDict(native.cast(), dict.length);
        if (ddict == nullptr) throw StateError('ZSTD_createDDict נכשל');
        freeDDict.attach(this, ddict.cast());
        _ddicts[_zstd.ZSTD_getDictID_fromDDict(ddict)] = ddict;
      } finally {
        malloc.free(native);
      }
    }
    _dctx = _zstd.ZSTD_createDCtx();
    if (_dctx == nullptr) throw StateError('ZSTD_createDCtx נכשל');
    freeDCtx.attach(this, _dctx.cast());
  }

  static NativeFinalizer? _freeDDict;
  static NativeFinalizer? _freeDCtx;

  late final ZstandardNativeBindings _zstd;
  final Map<int, Pointer<ZSTD_DDict>> _ddicts;
  late final Pointer<ZSTD_DCtx> _dctx;
  final _input = _GrowableNativeBuffer();
  final _output = _GrowableNativeBuffer();

  Uint8List decompress(Uint8List frame) {
    final src = _input.reserve(frame.length);
    src.asTypedList(frame.length).setAll(0, frame);
    final size = _zstd.ZSTD_getFrameContentSize(src.cast(), frame.length);
    // ZSTD_CONTENTSIZE_UNKNOWN/ERROR הם -1/-2 כשנקראים כ-int חתום.
    if (size < 0 || size > LineContentCodec.maxLineBytes) {
      throw FormatException('מסגרת zstd לא תקינה (גודל $size)');
    }
    final dictId = _zstd.ZSTD_getDictID_fromFrame(src.cast(), frame.length);
    final ddict = _ddicts[dictId];
    if (ddict == null) {
      throw FormatException('מילון $dictId חסר ב-zstd_dict');
    }
    final dst = _output.reserve(size);
    final written = _zstd.ZSTD_decompress_usingDDict(
      _dctx,
      dst.cast(),
      size,
      src.cast(),
      frame.length,
      ddict,
    );
    if (_zstd.ZSTD_isError(written) != 0 || written != size) {
      throw FormatException(
        'פענוח zstd נכשל: '
        '${_zstd.ZSTD_getErrorName(written).cast<Utf8>().toDartString()}',
      );
    }
    return Uint8List.fromList(dst.asTypedList(written));
  }
}

/// חוצץ נייטיב שגדל לפי הצורך ומשוחרר עם הבעלים שלו.
final class _GrowableNativeBuffer implements Finalizable {
  static final _finalizer = NativeFinalizer(malloc.nativeFree);

  Pointer<Uint8> _pointer = nullptr;
  int _capacity = 0;

  Pointer<Uint8> reserve(int bytes) {
    if (bytes <= _capacity && _pointer != nullptr) return _pointer;
    if (_pointer != nullptr) {
      _finalizer.detach(this);
      malloc.free(_pointer);
    }
    _capacity = bytes < 4096 ? 4096 : bytes + bytes ~/ 4;
    _pointer = malloc<Uint8>(_capacity);
    _finalizer.attach(this, _pointer.cast(), detach: this);
    return _pointer;
  }
}
