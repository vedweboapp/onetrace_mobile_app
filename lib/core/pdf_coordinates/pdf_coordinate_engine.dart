import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'pdf_annotation_point.dart';
import 'pdf_coordinate_transformer.dart';
import 'pdf_page_metadata_cache.dart';
import 'pdf_page_transform.dart';
import 'pdf_viewport_state.dart';

/// Matrix-based PDF ↔ viewport conversion (OneTrace / Bluebeam style).
///
/// **Why not widget percentages?** Different engines lay out pages with different
/// padding, fit modes, and DPR; only PDF user space + live viewport matrix is stable.
///
/// Pipeline:
/// 1. tap (viewport) → inverse matrix → document point on laid-out page rect
/// 2. document fraction → PDF user units (pdfX, pdfY) using media-box size
/// 3. reverse on paint whenever zoom/pan/resize changes
class PdfCoordinateEngine {
  PdfCoordinateEngine({
    required this.controller,
    required this.metadata,
  });

  final PdfControllerPinch controller;
  final PdfPageMetadataCache metadata;

  PdfViewportState get viewport => PdfViewportState.fromController(controller);

  // --- Screen / viewport ↔ PDF user space -----------------------------------

  /// **screen → PDF** (tap on overlay). Alias for [viewportToAnnotation].
  PdfAnnotationPoint? screenToPdf(Offset screenLocal) =>
      viewportToAnnotation(screenLocal);

  /// **PDF → screen** (pin render). Alias for [annotationToViewport].
  Offset? pdfToScreen(PdfAnnotationPoint point) => annotationToViewport(point);

  /// Per-page scale/offset in layout space (before viewport matrix).
  PdfPageTransform? pageTransform(int pageOneBased) {
    final meta = metadata.page(pageOneBased);
    final layout = safeGetPageRect(controller, pageOneBased);
    if (meta == null || layout == null) return null;
    final w = meta.width <= 0 ? 1.0 : meta.width;
    final h = meta.height <= 0 ? 1.0 : meta.height;
    return PdfPageTransform(
      page: pageOneBased,
      pdfPageWidth: w,
      pdfPageHeight: h,
      layoutRect: layout,
      scaleX: layout.width / w,
      scaleY: layout.height / h,
      layoutOffset: layout.topLeft,
    );
  }

  /// Tap on overlay → stored [PdfAnnotationPoint].
  PdfAnnotationPoint? viewportToAnnotation(Offset viewportLocal) {
    final doc = viewportLocalToDoc(controller, viewportLocal);
    final page =
        findPageContainingDoc(controller, doc) ??
        findNearestPage(controller, doc);
    if (page == null) return null;

    final layout = safeGetPageRect(controller, page);
    if (layout == null || layout.width <= 0 || layout.height <= 0) {
      return null;
    }

    final meta = metadata.page(page);
    if (meta == null) return null;

    final nx = ((doc.dx - layout.left) / layout.width).clamp(0.0, 1.0);
    final ny = ((doc.dy - layout.top) / layout.height).clamp(0.0, 1.0);

    return PdfAnnotationPoint.fromMetadata(
      metadata: meta,
      pdfX: nx * meta.width,
      pdfY: ny * meta.height,
    );
  }

  /// Stored pin → overlay [Positioned] offset (recomputed every frame).
  Offset? annotationToViewport(PdfAnnotationPoint point) {
    final meta = metadata.page(point.page);
    final layout = safeGetPageRect(controller, point.page);
    if (layout == null) return null;

    final boxW = point.pageWidth > 0 ? point.pageWidth : (meta?.width ?? 1);
    final boxH = point.pageHeight > 0 ? point.pageHeight : (meta?.height ?? 1);
    final nx = (point.pdfX / boxW).clamp(0.0, 1.0);
    final ny = (point.pdfY / boxH).clamp(0.0, 1.0);

    final doc = Offset(
      layout.left + nx * layout.width,
      layout.top + ny * layout.height,
    );
    return docToViewportLocal(controller, doc);
  }

  // --- Document/layout space (pdfx native, zoom-aware) ------------------------

  Offset viewportToDocument(Offset viewportLocal) =>
      viewportLocalToDoc(controller, viewportLocal);

  Offset documentToViewport(Offset documentPoint) =>
      docToViewportLocal(controller, documentPoint);

  // --- API percentage bridge (legacy web payloads) --------------------------

  PdfAnnotationPoint? annotationFromApiPercent({
    required dynamic xRaw,
    required dynamic yRaw,
    int page = 1,
  }) {
    final x = _toDouble(xRaw);
    final y = _toDouble(yRaw);
    if (x == null || y == null) return null;
    final meta = metadata.page(page);
    if (meta == null) return null;

    final nx = _normalizeApiScalar(x);
    final ny = _normalizeApiScalar(y);
    return PdfAnnotationPoint.fromMetadata(
      metadata: meta,
      pdfX: nx * meta.width,
      pdfY: ny * meta.height,
    );
  }

  Map<String, dynamic> annotationToApiPercent(PdfAnnotationPoint point) {
    final w = point.pageWidth > 0 ? point.pageWidth : 1.0;
    final h = point.pageHeight > 0 ? point.pageHeight : 1.0;
    return {
      'page': point.page,
      'x_coordinate': ((point.pdfX / w) * 100).round(),
      'y_coordinate': ((point.pdfY / h) * 100).round(),
    };
  }

  static double _normalizeApiScalar(double value) =>
      (value > 1 ? value / 100.0 : value).clamp(0.0, 1.0);

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }
}
