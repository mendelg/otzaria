import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:seforim_library_updater/seforim_library_updater.dart';

/// מחבר את החלקים ש-[manifestPath] (צורת split_release_asset.sh) מתאר אל
/// [outputPath], ומאמת כל חלק ואת השלם; בכשל הפלט נמחק ונזרקת [FormatException].
Future<void> joinSplitArchive(
  String manifestPath,
  String outputPath, {
  void Function(double progress)? onProgress,
}) async {
  final dir = path.dirname(manifestPath);
  final split = SplitAsset.fromManifestJson(
    jsonDecode(await File(manifestPath).readAsString()),
    manifestName: path.basename(manifestPath),
    partUrls: {
      for (final entity in Directory(dir).listSync())
        if (entity is File) path.basename(entity.path): entity.path,
    },
  );

  final whole = AccumulatorSink<Digest>();
  final wholeInput = sha256.startChunkedConversion(whole);
  final output = await File(outputPath).open(mode: FileMode.write);
  var written = 0;
  try {
    for (final part in split.parts) {
      final file = File(part.downloadUrl);
      if (await file.length() != part.size) {
        throw FormatException('החלק ${part.name} אינו בגודל הצפוי');
      }
      final partDigest = AccumulatorSink<Digest>();
      final partInput = sha256.startChunkedConversion(partDigest);
      await for (final chunk in file.openRead()) {
        partInput.add(chunk);
        wholeInput.add(chunk);
        await output.writeFrom(chunk);
        written += chunk.length;
        onProgress?.call(written / split.size);
      }
      partInput.close();
      if (partDigest.events.single.toString() != part.sha256) {
        throw FormatException('החלק ${part.name} פגום (sha256 אינו תואם)');
      }
    }
    wholeInput.close();
    if (whole.events.single.toString() != split.sha256) {
      throw FormatException('${split.archive} שחובר פגום (sha256 אינו תואם)');
    }
  } catch (_) {
    await output.close();
    await File(outputPath).delete().catchError((_) => File(outputPath));
    rethrow;
  }
  await output.close();
}
