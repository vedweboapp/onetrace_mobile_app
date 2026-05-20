import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'pdf_page_coordinate.dart';

/// Low-level PDF layout helpers (safe against empty document during first frame).
Rect? safeGetPageRect(PdfControllerPinch pdf, int pageOneBased) {
  final n = pdf.pagesCount ?? 0;
  if (n < 1 || pageOneBased < 1 || pageOneBased > n) return null;
  try {
    return pdf.getPageRect(pageOneBased);
  } on RangeError {
    return null;
  }
}

/// Viewport-local (overlay top-left) → document space via [PdfControllerPinch.value].
Offset viewportLocalToDoc(PdfControllerPinch c, Offset local) {
  final inv = Matrix4.inverted(c.value);
  return MatrixUtils.transformPoint(inv, local);
}

/// Document space → viewport-local (for [Positioned] / hit tests).
Offset docToViewportLocal(PdfControllerPinch c, Offset doc) {
  return MatrixUtils.transformPoint(c.value, doc);
}

int? findPageContainingDoc(PdfControllerPinch c, Offset doc) {
  final n = c.pagesCount ?? 0;
  for (var p = 1; p <= n; p++) {
    final r = safeGetPageRect(c, p);
    if (r != null && r.contains(doc)) return p;
  }
  return null;
}

int? findNearestPage(PdfControllerPinch c, Offset doc) {
  final n = c.pagesCount ?? 0;
  if (n == 0) return null;
  double best = double.infinity;
  int? bestP;
  for (var p = 1; p <= n; p++) {
    final r = safeGetPageRect(c, p);
    if (r == null) continue;
    final d = (r.center - doc).distance;
    if (d < best) {
      best = d;
      bestP = p;
    }
  }
  return bestP;
}

/// Converts a tap in overlay/viewport space to a stored [PdfPageCoordinate].
class PdfCoordinateTransformer {
  const PdfCoordinateTransformer._();

  static PdfPageCoordinate? fromViewportLocal(
    PdfControllerPinch controller,
    Offset viewportLocal,
  ) {
    final doc = viewportLocalToDoc(controller, viewportLocal);
    final page =
        findPageContainingDoc(controller, doc) ??
        findNearestPage(controller, doc);
    if (page == null) return null;
    final pr = safeGetPageRect(controller, page);
    if (pr == null || pr.width <= 0 || pr.height <= 0) return null;
    return PdfPageCoordinate(
      page: page,
      xPercent: ((doc.dx - pr.left) / pr.width).clamp(0.0, 1.0),
      yPercent: ((doc.dy - pr.top) / pr.height).clamp(0.0, 1.0),
    );
  }

  /// Renders a stored coordinate into overlay/viewport pixels (zoom-aware).
  static Offset? toViewportLocal(
    PdfControllerPinch controller,
    PdfPageCoordinate coord,
  ) {
    final pr = safeGetPageRect(controller, coord.page);
    if (pr == null) return null;
    final doc = Offset(
      pr.left + coord.xPercent * pr.width,
      pr.top + coord.yPercent * pr.height,
    );
    return docToViewportLocal(controller, doc);
  }

  /// Scene coords in [DrawingCanvasPage] match viewport-local when PDF fills the stack.
  static PdfPageCoordinate? fromScenePoint(
    PdfControllerPinch controller,
    Offset scenePoint,
  ) => fromViewportLocal(controller, scenePoint);

  static Offset? toScenePoint(
    PdfControllerPinch controller,
    PdfPageCoordinate coord,
  ) => toViewportLocal(controller, coord);
}
