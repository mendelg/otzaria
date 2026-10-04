import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/semantic_search/models/semantic_engine_models.dart';
import 'package:otzaria/semantic_search/models/semantic_failure.dart';
import 'package:otzaria/semantic_search/models/semantic_result_item.dart';
import 'package:otzaria/semantic_search/repository/semantic_results_source.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

import 'semantic_test_support.dart';

SemanticSearchResult _result(int n) => SemanticSearchResult(
  title: 'ספר $n',
  reference: 'ספר $n, א',
  snippetHtml: 'טקסט $n',
  isHighlighted: false,
  id: BigInt.from(n),
  segment: BigInt.from(n),
  isPdf: false,
  filePath: 'id:$n',
  mergedCount: 1,
  merged: const [],
  semanticScore: 0.6,
  fusedScore: 0.01,
  source: SemanticResultSource.semantic,
  needsHydration: false,
  textStatus: TextStatus.ok,
);

SemanticSearchResponse _response({
  required int results,
  required int totalCount,
  int? groupCount,
  required bool hasMore,
}) => SemanticSearchResponse(
  results: [for (var i = 1; i <= results; i++) _result(i)],
  totalCount: totalCount,
  lexicalTotalCount: 7,
  groupCount: groupCount,
  countsAreExact: false,
  requestedMode: SemanticRetrievalMode.hybrid,
  executedMode: SemanticExecutedMode.hybrid,
  semanticAvailable: true,
  latencyMs: BigInt.one,
  candidateWindowTruncated: false,
  truncated: false,
  hasMore: hasMore,
);

void main() {
  late Directory root;
  late FakeBackend backend;
  late EngineSemanticResultsSource source;

  setUp(() {
    root = Directory.systemTemp.createTempSync('semantic_source_');
    installModelFiles(root);
    backend = FakeBackend()..vectors = installedV30;
    source = EngineSemanticResultsSource(
      buildRepository(root: root, backend: backend),
    );
  });
  tearDown(() async {
    for (var attempt = 0; attempt < 5 && root.existsSync(); attempt++) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('הצד המילולי של החיפוש החכם: fuzzy במרחק 0', () async {
    await source.fetch(
      const SemanticQueryOptions(query: 'תפילין'),
      offset: 0,
      limit: 30,
    );

    final request = backend.searchRequests.last;
    expect(request.query, 'תפילין');
    expect(request.lexicalMode, SemanticLexicalMode.fuzzy);
    expect(request.effectiveFuzzyMaxDistance, 0);
  });

  test('יש עוד עמוד לפי hasMore של המנוע, לא לפי הספירות', () async {
    // הספירה מתארת חלון מועמדים: קטנה מהעמוד, ובכל זאת יש המשך.
    backend.response = _response(results: 3, totalCount: 3, hasMore: true);
    final more = await source.fetch(
      const SemanticQueryOptions(query: 'א'),
      offset: 0,
      limit: 3,
    );
    expect(more!.hasMore, isTrue);
    expect(more.totalCount, 3);

    backend.response = _response(
      results: 3,
      totalCount: 500,
      groupCount: 400,
      hasMore: false,
    );
    final last = await source.fetch(
      const SemanticQueryOptions(query: 'א'),
      offset: 3,
      limit: 3,
    );
    expect(last!.hasMore, isFalse);
    expect(last.totalCount, 500);
    expect(last.groupCount, 400);
  });

  test('סימון הקטע: יעד לכל פריט, בסדרם, והביטול מגיע למנוע', () async {
    await source.fetch(
      const SemanticQueryOptions(query: 'כבוד אב'),
      offset: 0,
      limit: 30,
    );
    final items = [
      for (final n in [4, 2]) SemanticResultItem.fromEngine(_result(n)),
    ];
    final cancel = SemanticCancelHandle();

    final marked = await source.passageHighlights('כבוד אב', items, cancel);

    expect(backend.calls.last, 'highlight:כבוד אב:2');
    expect(identical(backend.highlightHandles.single, cancel), isTrue);
    expect(marked.map((h) => h.id), [BigInt.from(4), BigInt.from(2)]);
    expect(marked.map((h) => h.filePath), ['id:4', 'id:2']);

    cancel.cancel();
    await expectLater(
      source.passageHighlights('כבוד אב', items, cancel),
      throwsA(
        isA<SemanticFailure>().having(
          (f) => f.kind,
          'kind',
          SemanticFailureKind.cancelled,
        ),
      ),
    );
  });
}
