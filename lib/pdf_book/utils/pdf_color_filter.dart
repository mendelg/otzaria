import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// צבע שמצויר בתוך שכבת ה-PDF יתהפך שוב במצב כהה.
Color pdfColorBeforeFilter(Color color, Brightness brightness) {
  if (brightness != Brightness.dark) return color;
  return Color.from(
    alpha: color.a,
    red: 1.0 - color.r,
    green: 1.0 - color.g,
    blue: 1.0 - color.b,
  );
}

/// היפוך צבעי ה-PDF במצב כהה. בבהיר אין שכבה כלל — ColorFiltered דוחף saveLayer
/// בכל פריים גם כשהוא שקוף — וצורת העץ זהה בשני המצבים כדי שה-viewer לא ייבנה מחדש.
class PdfDarkModeFilter extends SingleChildRenderObjectWidget {
  const PdfDarkModeFilter({super.key, required this.inverted, super.child});

  final bool inverted;

  static const invertColors = ColorFilter.mode(
    Colors.white,
    BlendMode.difference,
  );

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPdfDarkModeFilter(inverted);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPdfDarkModeFilter renderObject,
  ) {
    renderObject.inverted = inverted;
  }
}

class RenderPdfDarkModeFilter extends RenderProxyBox {
  RenderPdfDarkModeFilter(this._inverted);

  bool _inverted;
  set inverted(bool value) {
    if (value == _inverted) return;
    _inverted = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _inverted && child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_inverted) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushColorFilter(
      offset,
      PdfDarkModeFilter.invertColors,
      super.paint,
      oldLayer: layer as ColorFilterLayer?,
    );
  }
}
