import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/services/commentary_service.dart';

void main() {
  test('hasCommentaries מזהה שורת אמצע בטווח בלי לכלול שורה מחוץ לו', () {
    final links = [
      Link(
        heRef: 'א',
        index1: 2,
        index1End: 7,
        path2: 'רש"י',
        index2: 1,
        connectionType: 'COMMENTARY',
      ),
    ];
    bool hasAt(int index) => CommentaryService.hasCommentaries(
      indexes: [index],
      links: links,
      activeCommentators: ['רש"י'],
    );
    expect(hasAt(0), isFalse);
    expect(hasAt(4), isTrue);
    expect(hasAt(7), isFalse);
  });
}
