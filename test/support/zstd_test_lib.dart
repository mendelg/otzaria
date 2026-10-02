import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:zstandard_native/zstandard_native_bindings.dart';

/// libzstd לבדיקות: `OTZARIA_ZSTD_LIB`, ה-DLL של בניית Windows, או libzstd
/// של המערכת (ה-API זהה ל-bindings). null — אין, והבדיקה מדלגת.
DynamicLibrary? openZstdForTests() {
  final candidates = [
    ?Platform.environment['OTZARIA_ZSTD_LIB'],
    'build/windows/x64/runner/Release/zstandard_windows.dll',
    'build/windows/x64/runner/Debug/zstandard_windows.dll',
    'libzstd.so.1',
    'libzstd.so',
    '/opt/homebrew/lib/libzstd.dylib',
    '/usr/local/lib/libzstd.dylib',
  ];
  for (final candidate in candidates) {
    try {
      return DynamicLibrary.open(candidate);
    } catch (_) {}
  }
  return null;
}

/// מסגרת zstd אחת של [text] עם [dictionary], כמו שלב הדחיסה ב-SeforimLibrary.
Uint8List compressWithDictionary(
  DynamicLibrary lib,
  Uint8List text,
  Uint8List dictionary,
) {
  final zstd = ZstandardNativeBindings(lib);
  final ctx = zstd.ZSTD_createCCtx();
  final bound = zstd.ZSTD_compressBound(text.length);
  final src = malloc<Uint8>(text.length + 1);
  final dict = malloc<Uint8>(dictionary.length);
  final dst = malloc<Uint8>(bound);
  try {
    src.asTypedList(text.length).setAll(0, text);
    dict.asTypedList(dictionary.length).setAll(0, dictionary);
    final written = zstd.ZSTD_compress_usingDict(
      ctx,
      dst.cast(),
      bound,
      src.cast(),
      text.length,
      dict.cast(),
      dictionary.length,
      3,
    );
    if (zstd.ZSTD_isError(written) != 0) throw StateError('compress failed');
    return Uint8List.fromList(dst.asTypedList(written));
  } finally {
    zstd.ZSTD_freeCCtx(ctx);
    malloc
      ..free(src)
      ..free(dict)
      ..free(dst);
  }
}
