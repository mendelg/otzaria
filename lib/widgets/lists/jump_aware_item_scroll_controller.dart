import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// [ItemScrollController] שמודיע למאזינים לפני כל קפיצה לאינדקס.
///
/// הקפיצה מאפסת את היסט הגלילה סביב עוגן חדש, ובחירת טקסט שנשענת על ההיסט
/// נוחתת אחריה על טקסט אחר.
class JumpAwareItemScrollController extends ItemScrollController {
  final _beforeJumpListeners = ObserverList<VoidCallback>();

  void addBeforeJumpListener(VoidCallback listener) =>
      _beforeJumpListeners.add(listener);

  void removeBeforeJumpListener(VoidCallback listener) =>
      _beforeJumpListeners.remove(listener);

  void _notifyBeforeJump() {
    for (final listener in _beforeJumpListeners.toList()) {
      listener();
    }
  }

  @override
  void jumpTo({required int index, double alignment = 0}) {
    _notifyBeforeJump();
    super.jumpTo(index: index, alignment: alignment);
  }

  @override
  Future<void> scrollTo({
    required int index,
    double alignment = 0,
    required Duration duration,
    Curve curve = Curves.linear,
    List<double> opacityAnimationWeights = const [40, 20, 40],
  }) {
    _notifyBeforeJump();
    return super.scrollTo(
      index: index,
      alignment: alignment,
      duration: duration,
      curve: curve,
      opacityAnimationWeights: opacityAnimationWeights,
    );
  }
}
