import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/messages/semantic_search_messages.dart';
import 'package:otzaria/search_feedback/search_feedback_api.dart';
import 'package:otzaria/semantic_search/models/semantic_availability.dart';
import 'package:otzaria/semantic_search/models/semantic_failure.dart';
import 'package:otzaria/semantic_search/models/semantic_import_layout.dart';
import 'package:otzaria/semantic_search/models/semantic_model_identity.dart';
import 'package:otzaria/semantic_search/models/semantic_model_release.dart';
import 'package:otzaria/semantic_search/models/semantic_paths.dart';
import 'package:otzaria/semantic_search/models/semantic_vectors_release.dart';
import 'package:otzaria/semantic_search/repository/semantic_release_locator.dart';
import 'package:otzaria/semantic_search/repository/semantic_staged_import.dart';
import 'package:otzaria/semantic_search/semantic_work_status.dart';
import 'package:otzaria/utils/file/disk_free_space.dart';
import 'package:path/path.dart' as p;

import 'semantic_test_support.dart';

const _tag = 'v30-20260930165019';
const _segmentName = 'otzaria-vectors-0c3f95be-v30-base.oxv.zst';
const _manifestName = 'otzaria-vectors-0c3f95be-v30-base.manifest.json';

String _sha(List<int> bytes) => sha256.convert(bytes).toString();

SemanticModelFile _modelFile(String name, String content) => SemanticModelFile(
  name: name,
  size: utf8.encode(content).length,
  sha256: _sha(utf8.encode(content)),
);

/// release מודל קטן, כדי שקבצים מוכנים יתאימו לו בבדיקה.
final Map<SemanticQuantization, SemanticModelRelease?> _smallModel = {
  SemanticQuantization.int8: SemanticModelRelease(
    baseUrl: 'https://models.test/meivin',
    graph: _modelFile(SemanticQuantization.int8.modelFileName, 'graph'),
    tokenizer: _modelFile(kSemanticTokenizerFileName, 'tokenizer'),
    identity: _modelFile(kSemanticModelIdentityFileName, bundledModelJson()),
    license: _modelFile(kSemanticModelLicenseFileName, 'license'),
  ),
  SemanticQuantization.fp32: null,
};

/// מניפסט וקטורים בצורה שמתפרסמת ב-SeforimLibrary.
String _manifest({String segment = 'segment', int version = 30}) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': 'otzaria-vectors-release',
      'kind': 'base',
      'fromLibraryVersion': 0,
      'toLibraryVersion': version,
      'libraryReleaseTag': 'v$version-20260930165019',
      'segment': {'sha256': 'cd' * 32, 'size': 99},
      'files': [
        {
          'file': _segmentName,
          'sha256': _sha(utf8.encode(segment)),
          'size': utf8.encode(segment).length,
        },
      ],
    });

class _UnreachableLocator extends SemanticVectorsReleaseLocator {
  int lookups = 0;

  @override
  Future<SemanticVectorsRelease?> findForLibraryVersion(
    int libraryVersion, {
    String? libraryTag,
  }) async {
    lookups++;
    throw const SocketException('no network');
  }
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('semantic_staged_'));
  tearDown(() async {
    for (var attempt = 0; attempt < 5 && root.existsSync(); attempt++) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  SemanticPaths paths() => SemanticPaths(p.join(root.path, 'otzaria'));
  String staged(String folder, String name) => p.join(
    root.path,
    kSemanticImportFolderName,
    folder,
    name,
  );

  void write(String path, String content) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  /// מה שמסייע ההורדה מכין: קובצי המודל, ה-segment והמניפסט.
  String stageAll({String segment = 'segment'}) {
    final model = _smallModel[SemanticQuantization.int8]!;
    write(staged(kSemanticModelFolderName, model.graph.name), 'graph');
    write(staged(kSemanticModelFolderName, model.tokenizer.name), 'tokenizer');
    write(
      staged(kSemanticModelFolderName, model.identity.name),
      bundledModelJson(),
    );
    write(staged(kSemanticModelFolderName, model.license.name), 'license');
    write(staged(kSemanticImportVectorsFolderName, _segmentName), segment);
    final manifest = _manifest();
    write(staged(kSemanticImportVectorsFolderName, _manifestName), manifest);
    return manifest;
  }

  test('נתונים מוכנים ותקינים מותקנים בלי רשת', () async {
    final manifest = stageAll();
    final backend = FakeBackend();
    final downloads = FakeDownloads()..error = const SocketException('none');
    final locator = _UnreachableLocator();
    final repository = buildRepository(
      root: root,
      backend: backend,
      locator: locator,
      download: downloads.call,
      modelReleases: _smallModel,
    );

    await repository.enableAndDownload();

    expect(downloads.urls, isEmpty, reason: 'שום קובץ לא ירד');
    expect(locator.lookups, 1);
    final install = backend.installRequests.single;
    expect(install.manifestJson, manifest);
    expect(install.publishedManifestSha256, _sha(utf8.encode(manifest)));
    expect(
      install.segmentPath,
      p.join(paths().vectorsDownloadDirectory, _segmentName),
    );
    expect(
      File(paths().modelFile(SemanticQuantization.int8)).readAsStringSync(),
      'graph',
    );
    expect(File(paths().tokenizerFile).existsSync(), isTrue);
    expect(File(paths().licenseFile).existsSync(), isTrue);
    expect(
      File(staged(kSemanticImportVectorsFolderName, _segmentName)).existsSync(),
      isFalse,
      reason: 'הקובץ הועבר ולא שוכפל',
    );
    expect(repository.availability.phase, SemanticAvailabilityPhase.ready);
  });

  test('במצב לא מקוון — מותקן מהנתונים המוכנים בלי לפנות לרשת', () async {
    stageAll();
    final backend = FakeBackend();
    final downloads = FakeDownloads();
    final locator = FakeLocator(releaseV30());
    final repository = buildRepository(
      root: root,
      backend: backend,
      settings: FakeSettingsStore()..isOfflineMode = true,
      locator: locator,
      download: downloads.call,
      modelReleases: _smallModel,
    );

    await repository.enableAndDownload();

    expect(locator.lookups, isEmpty);
    expect(downloads.urls, isEmpty);
    expect(backend.installRequests, hasLength(1));
  });

  test('קובץ מוכן שאינו תואם — יורד מהרשת במקומו', () async {
    stageAll(segment: 'corrupted');
    final release = SemanticStagedImport.parseStagedManifest(
      utf8.encode(_manifest()),
      30,
    )!;
    final backend = FakeBackend();
    final downloads = FakeDownloads();
    final repository = buildRepository(
      root: root,
      backend: backend,
      locator: FakeLocator(release),
      download: downloads.call,
      modelReleases: _smallModel,
    );

    await repository.enableAndDownload();

    expect(downloads.urls, [semanticVectorsAssetUrl(_tag, _segmentName)]);
    expect(backend.installRequests, hasLength(1));
    expect(
      File(staged(kSemanticImportVectorsFolderName, _segmentName)).existsSync(),
      isTrue,
      reason: 'קובץ שאינו תואם אינו נוגע',
    );
  });

  test('בלי הסכמה — דבר אינו מותקן והנתונים המוכנים נשארים', () async {
    stageAll();
    final backend = FakeBackend();
    final downloads = FakeDownloads();
    final repository = buildRepository(
      root: root,
      backend: backend,
      consent: FakeConsentStore(SearchFeedbackConsent.declined),
      download: downloads.call,
      modelReleases: _smallModel,
    );

    await repository.enableAndDownload();
    repository.scheduleVectorsUpdate();
    await repository.pendingJob;

    expect(backend.installRequests, isEmpty);
    expect(downloads.urls, isEmpty);
    expect(Directory(paths().modelDirectory).existsSync(), isFalse);
    expect(
      File(staged(kSemanticImportVectorsFolderName, _segmentName)).existsSync(),
      isTrue,
    );
    expect(
      repository.availability.phase,
      SemanticAvailabilityPhase.consentRequired,
    );
  });

  test('מניפסט מוכן של גרסת ספרייה אחרת אינו משמש', () {
    expect(
      SemanticStagedImport.parseStagedManifest(
        utf8.encode(_manifest(version: 29)),
        30,
      ),
      isNull,
    );
    expect(
      () => SemanticStagedImport.parseStagedManifest(
        utf8.encode(
          '{"kind":"base","toLibraryVersion":30,'
          '"libraryReleaseTag":"$_tag","files":[{"file":"../x",'
          '"size":1,"sha256":"aa"}],"segment":{"size":1}}',
        ),
        30,
      ),
      throwsFormatException,
    );
  });

  test('בלי רשת ובלי נתונים מוכנים — הכשל המקורי נשאר', () async {
    final repository = buildRepository(
      root: root,
      locator: _UnreachableLocator(),
      modelReleases: _smallModel,
    );

    await repository.enableAndDownload();

    expect(
      repository.availability.failure?.kind,
      SemanticFailureKind.network,
    );
  });

  test('בדיקת קובץ מוכן היא שלב בלי מדידה, והבתים נספרים בסך הכולל', () async {
    stageAll();
    final backend = FakeBackend();
    final repository = buildRepository(
      root: root,
      backend: backend,
      locator: _UnreachableLocator(),
      download: (FakeDownloads()..error = const SocketException('none')).call,
      modelReleases: _smallModel,
    );
    final seen = <SemanticDownloadProgress>[];
    final subscription = repository.availabilityChanges.listen((a) {
      final progress = a.progress;
      if (progress != null) seen.add(progress);
    });

    await repository.enableAndDownload();
    await subscription.cancel();

    final checking = seen.where((p) => p.checking).toList();
    // ארבעה קובצי מודל ו-segment אחד.
    expect(checking, hasLength(5));
    expect(checking.every((p) => p.fraction == null), isTrue);
    expect(checking.first.item, SemanticDownloadItem.model);
    expect(checking.last.item, SemanticDownloadItem.vectors);
    expect(
      SemanticSearchMessages.progressLabel(checking.last),
      'שלב 2 מתוך 3 — בודק את הקבצים שהוכנו מראש',
    );
    expect(
      semanticWorkStatusItem(
        SemanticAvailability(
          phase: SemanticAvailabilityPhase.downloading,
          consentGranted: true,
          progress: checking.last,
        ),
        afterJob: false,
        onCancel: () {},
        onRetry: () {},
      )!.progress,
      isNull,
      reason: 'טבעת בלי ערך בזמן הבדיקה',
    );
    final total = checking.first.totalBytes!;
    final model = _smallModel[SemanticQuantization.int8]!;
    expect(total, model.downloadSize + utf8.encode('segment').length);
    final lastDownload = seen.lastWhere(
      (p) => p.item == SemanticDownloadItem.vectors && !p.checking,
    );
    expect(lastDownload.receivedBytes, total);
    expect(backend.installRequests, hasLength(1));
  });

  group('מקום פנוי', () {
    // segment של 7 בתים, ו-99 בתים פרוסים; 100 פנויים מספיקים רק בלי ההורדה.
    Future<SemanticFailureKind?> run(String stagedVolume) async {
      stageAll();
      final backend = FakeBackend();
      final repository = buildRepository(
        root: root,
        backend: backend,
        locator: _UnreachableLocator(),
        modelReleases: _smallModel,
        diskSpace: (path) async => DiskSpaceInfo(
          volumeId: path.contains(kSemanticImportFolderName)
              ? stagedVolume
              : 'C',
          freeBytes: 100,
        ),
      );
      await repository.enableAndDownload();
      return repository.availability.failure?.kind;
    }

    test('קובץ מוכן באותו כונן אינו נספר', () async {
      expect(await run('C'), isNull);
    });

    test('קובץ מוכן בכונן אחר — ההעתקה נספרת', () async {
      expect(await run('D'), SemanticFailureKind.insufficientDiskSpace);
    });
  });
}
