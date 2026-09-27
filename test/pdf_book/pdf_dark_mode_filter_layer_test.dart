import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/utils/pdf_color_filter.dart';

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFFDBDBDB), child: SizedBox.expand());
}

List<ColorFilterLayer> _colorFilterLayers(WidgetTester tester) {
  final found = <ColorFilterLayer>[];
  void visit(Layer layer) {
    if (layer is ColorFilterLayer) found.add(layer);
    if (layer is ContainerLayer) {
      for (
        var child = layer.firstChild;
        child != null;
        child = child.nextSibling
      ) {
        visit(child);
      }
    }
  }

  visit(tester.binding.renderViews.first.debugLayer!);
  return found;
}

Widget _app(bool inverted) => Directionality(
  textDirection: TextDirection.rtl,
  child: RepaintBoundary(
    child: PdfDarkModeFilter(inverted: inverted, child: const _Probe()),
  ),
);

void main() {
  testWidgets('מצב בהיר — אין שכבת סינון צבע כלל', (tester) async {
    await tester.pumpWidget(_app(false));
    expect(_colorFilterLayers(tester), isEmpty);
  });

  testWidgets('מצב כהה — שכבת היפוך אחת', (tester) async {
    await tester.pumpWidget(_app(true));
    final layers = _colorFilterLayers(tester);
    expect(layers, hasLength(1));
    expect(layers.single.colorFilter, PdfDarkModeFilter.invertColors);
  });

  testWidgets(
    'מעבר בין המצבים שומר את ה-State של התוכן (ה-viewer לא נבנה מחדש)',
    (
      tester,
    ) async {
      await tester.pumpWidget(_app(false));
      final before = tester.state<_ProbeState>(find.byType(_Probe));

      await tester.pumpWidget(_app(true));
      expect(tester.state<_ProbeState>(find.byType(_Probe)), same(before));
      expect(_colorFilterLayers(tester), hasLength(1));

      await tester.pumpWidget(_app(false));
      expect(tester.state<_ProbeState>(find.byType(_Probe)), same(before));
      expect(_colorFilterLayers(tester), isEmpty);
    },
  );
}
