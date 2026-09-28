import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/pdf_book/bloc/pdf_book_state.dart';
import 'package:pdfrx/pdfrx.dart';

PdfOutlineNode _node(
  String title,
  int page, [
  List<PdfOutlineNode>? children,
]) => PdfOutlineNode(
  title: title,
  dest: PdfDest(page, PdfDestCommand.fit, null),
  children: children ?? const [],
);

Link _link(int index1, String heRef) => Link(
  heRef: heRef,
  index1: index1,
  path2: 'רש"י.txt',
  index2: 1,
  connectionType: 'commentary',
);

PdfBookLoaded _state({List<PdfOutlineNode>? outline, List<Link>? links}) =>
    PdfBookLoaded(
      book: PdfBook(title: 'ספר', path: '/x.pdf'),
      currentPageNumber: 1,
      totalPages: 10,
      isLoading: false,
      outline: outline,
      links: links ?? const [],
    );

void main() {
  test('אותה רשימה (copyWith) — שווה', () {
    final outline = [
      _node('א', 1, [_node('ב', 2)]),
    ];
    final links = [_link(1, 'א')];
    final state = _state(outline: outline, links: links);
    expect(state.copyWith(zoom: 2), isNot(state));
    expect(state.copyWith(zoom: 2), state.copyWith(zoom: 2));
  });

  test('רשימה חדשה עם אותו תוכן — שווה (בלי emit מיותר)', () {
    final a = _state(
      outline: [
        _node('א', 1, [_node('ב', 2)]),
      ],
      links: [_link(1, 'א')],
    );
    final b = _state(
      outline: [
        _node('א', 1, [_node('ב', 2)]),
      ],
      links: [_link(1, 'א')],
    );
    expect(a, b);
  });

  test('תוכן שונה באותו אורך — שונה', () {
    expect(
      _state(links: [_link(1, 'א')]),
      isNot(_state(links: [_link(2, 'ב')])),
    );
    expect(
      _state(
        outline: [
          _node('א', 1, [_node('ב', 2)]),
        ],
      ),
      isNot(
        _state(
          outline: [
            _node('א', 1, [_node('ג', 2)]),
          ],
        ),
      ),
    );
  });

  test('outline חסר מול ריק — שונה', () {
    expect(_state(outline: null), isNot(_state(outline: const [])));
  });
}
