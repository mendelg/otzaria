import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:zstandard_native/zstandard_native_bindings.dart';

/// מפענח zstd בזרימה שמוזן בנתחים מכל מקור (חלקים, ערוץ SAF) ומוסר את
/// הפלט לצרכן סינכרוני, בלי קובץ ביניים.
class ZstdStreamDecoder {
  ZstdStreamDecoder(DynamicLibrary lib) : _zstd = ZstandardNativeBindings(lib) {
    _inSize = _zstd.ZSTD_DStreamInSize();
    _outSize = _zstd.ZSTD_DStreamOutSize();
    _stream = _zstd.ZSTD_createDStream();
    if (_stream == nullptr) throw StateError('ZSTD_createDStream נכשל');
    _inNative = malloc.allocate<Uint8>(_inSize);
    _outNative = malloc.allocate<Uint8>(_outSize);
    _inBuf = malloc<ZSTD_inBuffer_s>();
    _outBuf = malloc<ZSTD_outBuffer_s>();
    _check(_zstd.ZSTD_initDStream(_stream), 'ZSTD_initDStream');
    // ארכיון שנדחס עם --long דורש חלון גדול מברירת המחדל (128MB).
    // ב-32 ביט (armeabi-v7a) zstd דוחה 31 — התקרה שם היא 30.
    _check(
      _zstd.ZSTD_DCtx_setParameter(
        _stream,
        ZSTD_dParameter.ZSTD_d_windowLogMax,
        sizeOf<IntPtr>() == 4 ? 30 : 31,
      ),
      'ZSTD_DCtx_setParameter',
    );
  }

  final ZstandardNativeBindings _zstd;
  late final int _inSize;
  late final int _outSize;
  late final Pointer<ZSTD_DCtx> _stream;
  late final Pointer<Uint8> _inNative;
  late final Pointer<Uint8> _outNative;
  late final Pointer<ZSTD_inBuffer_s> _inBuf;
  late final Pointer<ZSTD_outBuffer_s> _outBuf;
  int _lastRet = 0;
  bool _fedAny = false;
  bool _disposed = false;

  void _check(int code, String what) {
    if (_zstd.ZSTD_isError(code) != 0) {
      final name = _zstd.ZSTD_getErrorName(code).cast<Utf8>().toDartString();
      throw FormatException('$what נכשל: $name');
    }
  }

  /// מפענח את [input]. [onOutput] מקבל תצוגה על זיכרון נייטיב שתקפה רק
  /// בתוך הקריאה — הצרכן חייב לכתוב/להעתיק אותה מיד.
  void add(List<int> input, void Function(Uint8List output) onOutput) {
    var offset = 0;
    final inView = _inNative.asTypedList(_inSize);
    while (offset < input.length) {
      final take = (input.length - offset).clamp(0, _inSize);
      inView.setRange(0, take, input, offset);
      offset += take;
      _fedAny = true;
      _inBuf.ref
        ..src = _inNative.cast()
        ..size = take
        ..pos = 0;
      while (_inBuf.ref.pos < _inBuf.ref.size) {
        _outBuf.ref
          ..dst = _outNative.cast()
          ..size = _outSize
          ..pos = 0;
        _lastRet = _zstd.ZSTD_decompressStream(_stream, _outBuf, _inBuf);
        _check(_lastRet, 'פענוח zstd');
        if (_outBuf.ref.pos > 0) {
          onOutput(_outNative.asTypedList(_outBuf.ref.pos));
        }
      }
    }
  }

  /// מוודא שהקלט הסתיים בסוף frame שלם — אחרת הארכיון קטוע.
  void close() {
    if (!_fedAny || _lastRet != 0) {
      throw const FormatException('הארכיון קטוע — ייתכן שחסר חלק בסופו');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _zstd.ZSTD_freeDStream(_stream);
    malloc
      ..free(_inNative)
      ..free(_outNative)
      ..free(_inBuf)
      ..free(_outBuf);
  }

  /// האם הקלט מתחיל ב-frame של zstd שנושא checksum של התוכן. בלי מניפסט
  /// זה האימות היחיד ששינוי בתוכן ייתפס.
  static bool frameHasContentChecksum(List<int> head) {
    if (head.length < 5) return false;
    final isMagic =
        head[0] == 0x28 &&
        head[1] == 0xB5 &&
        head[2] == 0x2F &&
        head[3] == 0xFD;
    return isMagic && (head[4] & 0x04) != 0;
  }
}
