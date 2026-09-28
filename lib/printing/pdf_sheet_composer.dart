/// Places the pages of a PDF several to a sheet, keeping them vector.
///
/// PDFium does the composition (`FPDF_ImportNPagesToOne`): each page becomes a
/// form object scaled into its cell, so text stays text at any print
/// resolution and the output is no larger than the source.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium_bindings;
import 'package:pdfrx/pdfrx.dart';

/// Source page index for each slot, in the order PDFium fills a sheet: rows
/// top to bottom, cells left to right. Null is a blank slot.
///
/// Right-to-left sheets put the first page of each row on the right, as a
/// Hebrew book is read. Blank slots appear only where a later page needs its
/// place kept, so the last sheet is not padded with empty pages.
@visibleForTesting
List<int?> sheetSlotOrder({
  required int firstIndex,
  required int lastIndex,
  required int rows,
  required int cols,
  bool rightToLeft = true,
}) {
  final count = lastIndex - firstIndex + 1;
  final cells = rows * cols;
  final slots = <int?>[];
  for (var sheet = 0; sheet * cells < count; sheet++) {
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final logicalCol = rightToLeft ? cols - 1 - col : col;
        final offset = sheet * cells + row * cols + logicalCol;
        slots.add(offset < count ? firstIndex + offset : null);
      }
    }
  }
  while (slots.isNotEmpty && slots.last == null) {
    slots.removeLast();
  }
  return slots;
}

/// Composes the pages `firstIndex`..`lastIndex` (zero-based) of `document`
/// onto sheets of `sheetWidth` x `sheetHeight` points, `rows` x `cols` each.
///
/// A single cell copies the pages at their own size, which is how a page range
/// alone is printed. `document` must stay open until this completes.
Future<Uint8List> composePdfSheets(
  PdfDocument document, {
  required int firstIndex,
  required int lastIndex,
  required int rows,
  required int cols,
  required double sheetWidth,
  required double sheetHeight,
  bool rightToLeft = true,
}) async {
  final handle = await document.useNativeDocumentHandle((handle) => handle);
  // Runs on PDFium's own worker isolate, where every other PDFium call runs,
  // so it neither races them nor blocks the UI while a long book is composed.
  return PdfrxEntryFunctions.instance.compute(_compose, (
    document: handle,
    modulePath: Pdfrx.pdfiumModulePath,
    slots: sheetSlotOrder(
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      rows: rows,
      cols: cols,
      rightToLeft: rightToLeft,
    ),
    rows: rows,
    cols: cols,
    sheetWidth: sheetWidth,
    sheetHeight: sheetHeight,
    rightToLeft: rightToLeft,
  ));
}

typedef _ComposeRequest = ({
  int document,
  String? modulePath,
  List<int?> slots,
  int rows,
  int cols,
  double sheetWidth,
  double sheetHeight,
  bool rightToLeft,
});

typedef _WriteBlock =
    Int Function(
      Pointer<pdfium_bindings.FPDF_FILEWRITE>,
      Pointer<Void>,
      UnsignedLong,
    );

/// `FPDF_SaveAsCopy` flag: write the whole file rather than an update.
const int _noIncremental = 2;

Uint8List _compose(_ComposeRequest request) {
  final pdfium = pdfium_bindings.getPdfium(modulePath: request.modulePath);
  final source = pdfium_bindings.FPDF_DOCUMENT.fromAddress(request.document);
  return using((arena) {
    final arranged = pdfium.FPDF_CreateNewDocument();
    pdfium_bindings.FPDF_DOCUMENT? sheets;
    try {
      _arrange(pdfium, source, arranged, request.slots, arena);
      final single = request.rows * request.cols == 1;
      final output = single
          ? arranged
          : sheets = pdfium.FPDF_ImportNPagesToOne(
              arranged,
              request.sheetWidth,
              request.sheetHeight,
              request.cols,
              request.rows,
            );
      if (output.address == 0) {
        throw StateError('PDFium could not compose the sheets.');
      }
      if (!single && request.rightToLeft) {
        _putCellsInReadingOrder(pdfium, output, request, arena);
      }
      return _save(pdfium, output, arena);
    } finally {
      if (sheets != null && sheets.address != 0) {
        pdfium.FPDF_CloseDocument(sheets);
      }
      pdfium.FPDF_CloseDocument(arranged);
    }
  });
}

/// Copies the source pages into `target` in slot order, with a blank page of
/// the first page's size wherever a slot is empty.
void _arrange(
  pdfium_bindings.PDFium pdfium,
  pdfium_bindings.FPDF_DOCUMENT source,
  pdfium_bindings.FPDF_DOCUMENT target,
  List<int?> slots,
  Arena arena,
) {
  final firstPage = slots.firstWhere((slot) => slot != null)!;
  final width = arena<Double>();
  final height = arena<Double>();
  pdfium.FPDF_GetPageSizeByIndex(source, firstPage, width, height);

  final indices = arena<Int>(slots.length);
  var start = 0;
  while (start < slots.length) {
    if (slots[start] == null) {
      final page = pdfium.FPDFPage_New(
        target,
        start,
        width.value,
        height.value,
      );
      pdfium.FPDF_ClosePage(page);
      start++;
      continue;
    }
    // Consecutive pages go over in one call.
    var end = start;
    while (end < slots.length && slots[end] != null) {
      indices[end - start] = slots[end]!;
      end++;
    }
    final imported = pdfium.FPDF_ImportPagesByIndex(
      target,
      source,
      indices,
      end - start,
      start,
    );
    if (imported == 0) {
      throw StateError('PDFium could not copy the pages.');
    }
    start = end;
  }
}

/// PDFium writes a sheet's cells left to right, which is also the order text
/// is selected and extracted in; right-to-left sheets need the right cell first.
void _putCellsInReadingOrder(
  pdfium_bindings.PDFium pdfium,
  pdfium_bindings.FPDF_DOCUMENT sheets,
  _ComposeRequest request,
  Arena arena,
) {
  final cellWidth = request.sheetWidth / request.cols;
  final cellHeight = request.sheetHeight / request.rows;
  final left = arena<Float>();
  final bottom = arena<Float>();
  final right = arena<Float>();
  final top = arena<Float>();

  int readingIndex(pdfium_bindings.FPDF_PAGEOBJECT object) {
    // An empty cell's form has no bounds; its place in the order is moot.
    if (pdfium.FPDFPageObj_GetBounds(object, left, bottom, right, top) == 0) {
      return 1 << 30;
    }
    final centerX = (left.value + right.value) / 2;
    final centerY = (bottom.value + top.value) / 2;
    final row = ((request.sheetHeight - centerY) / cellHeight).floor();
    final col = (centerX / cellWidth).floor();
    return row * request.cols + (request.cols - 1 - col);
  }

  for (var index = 0; index < pdfium.FPDF_GetPageCount(sheets); index++) {
    final page = pdfium.FPDF_LoadPage(sheets, index);
    if (page.address == 0) {
      throw StateError('PDFium could not reopen sheet ${index + 1}.');
    }
    try {
      final objects = [
        for (var i = 0; i < pdfium.FPDFPage_CountObjects(page); i++)
          pdfium.FPDFPage_GetObject(page, i),
      ];
      final order = {
        for (final object in objects) object: readingIndex(object),
      };
      final sorted = [...objects]
        ..sort((a, b) => order[a]!.compareTo(order[b]!));
      for (final object in objects) {
        pdfium.FPDFPage_RemoveObject(page, object);
      }
      for (final object in sorted) {
        pdfium.FPDFPage_InsertObject(page, object);
      }
      if (pdfium.FPDFPage_GenerateContent(page) == 0) {
        throw StateError('PDFium could not rewrite sheet ${index + 1}.');
      }
    } finally {
      pdfium.FPDF_ClosePage(page);
    }
  }
}

Uint8List _save(
  pdfium_bindings.PDFium pdfium,
  pdfium_bindings.FPDF_DOCUMENT document,
  Arena arena,
) {
  final output = BytesBuilder();
  int write(
    Pointer<pdfium_bindings.FPDF_FILEWRITE> _,
    Pointer<Void> data,
    int size,
  ) {
    // The buffer is PDFium's and is reused after this returns, so it is copied.
    output.add(data.cast<Uint8>().asTypedList(size));
    return 1;
  }

  final callback = NativeCallable<_WriteBlock>.isolateLocal(
    write,
    exceptionalReturn: 0,
  );
  try {
    final fileWrite = arena<pdfium_bindings.FPDF_FILEWRITE>();
    fileWrite.ref
      ..version = 1
      ..WriteBlock = callback.nativeFunction;
    if (pdfium.FPDF_SaveAsCopy(document, fileWrite, _noIncremental) == 0) {
      throw StateError('PDFium could not write the sheets.');
    }
    return output.takeBytes();
  } finally {
    callback.close();
  }
}
