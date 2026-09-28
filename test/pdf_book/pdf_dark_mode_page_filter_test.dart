import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/utils/pdf_color_filter.dart';
import 'package:otzaria/theme/app_surfaces.dart';

/// מצב כהה מסנן רק את ציור תוכן העמודים; הדגשות וקישוט נצבעים בצבעי התמה.
class _PageWithOverlayPainter extends CustomPainter {
  const _PageWithOverlayPainter(this.brightness, this.overlay);

  final Brightness brightness;
  final Color overlay;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..colorFilter = pdfPageColorFilter(brightness),
    );
    canvas.drawRect(rect, Paint()..color = overlay);
  }

  @override
  bool shouldRepaint(_PageWithOverlayPainter oldDelegate) => true;
}

void main() {
  void expectClose(Color actual, Color expected) {
    expect(actual.a, closeTo(expected.a, 0.01));
    expect(actual.r, closeTo(expected.r, 0.01));
    expect(actual.g, closeTo(expected.g, 0.01));
    expect(actual.b, closeTo(expected.b, 0.01));
  }

  Future<Color> centerPixel(WidgetTester tester, CustomPainter painter) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: CustomPaint(size: const Size.square(24), painter: painter),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offset = (12 * image.width + 12) * 4;
      final color = Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
      image.dispose();
      return color;
    }))!;
  }

  test('בבהיר אין מסנן כלל', () {
    expect(pdfPageColorFilter(Brightness.light), isNull);
    expect(pdfPageColorFilter(Brightness.dark), pdfInvertColors);
  });

  testWidgets('עמוד לבן מצויר בצבע הנייר של המצב', (tester) async {
    for (final brightness in Brightness.values) {
      final actual = await centerPixel(
        tester,
        _PageWithOverlayPainter(brightness, Colors.transparent),
      );
      expectClose(actual, pdfPageColor(brightness));
    }
  });

  testWidgets('הדגשת קישור נשארת בצבע התמה מעל העמוד ההפוך', (tester) async {
    for (final brightness in Brightness.values) {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B4F2A),
        brightness: brightness,
      );
      final hover = AppSurfaces.pdfLinkHover(scheme);
      final actual = await centerPixel(
        tester,
        _PageWithOverlayPainter(brightness, hover),
      );
      expectClose(actual, Color.alphaBlend(hover, pdfPageColor(brightness)));
    }
  });

  test('אין שכבת סינון על כל הצפיין', () {
    final code = File(
      'lib/pdf_book/view/pdf_book_screen.dart',
    ).readAsStringSync();
    expect(code, isNot(contains('ColorFiltered(')));
    expect(code, isNot(contains('pushColorFilter')));
    expect(code, isNot(contains('saveLayer(')));
  });
}
