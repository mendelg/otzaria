import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/book_source.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/text_book/text_book_repository.dart';

Link _link({
  int? index1End,
  int? targetCategoryId,
  int? anchorStart,
  BookSource targetSource = BookSource.official,
}) => Link(
  heRef: 'א',
  index1: 1,
  index1End: index1End,
  path2: 'מפרש',
  index2: 1,
  connectionType: 'COMMENTARY',
  targetCategoryId: targetCategoryId,
  targetSource: targetSource,
  anchorStart: anchorStart,
);

void main() {
  test('mergeExtraLinks משמר טווחים, עוגנים ומקורות יעד שונים', () {
    final links = [
      _link(index1End: 3),
      _link(index1End: 4),
      _link(anchorStart: 2),
      _link(anchorStart: 5),
      _link(targetCategoryId: 1),
      _link(targetCategoryId: 2),
      _link(targetSource: BookSource.user),
    ];
    expect(TextBookRepository.mergeExtraLinks([], links), links);
    expect(TextBookRepository.mergeExtraLinks([links.first], [links.first]), [
      links.first,
    ]);
  });
}
