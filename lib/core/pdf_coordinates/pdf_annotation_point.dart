import 'package:flutter/foundation.dart';

import 'pdf_page_metadata.dart';

/// Pin/plot position in true PDF user space — NOT screen pixels or widget %.
///
/// Persisted relative to [pageWidth] × [pageHeight] from the PDF media box so
/// web (PDF.js) and mobile (pdfx) resolve the same physical point.
@immutable
class PdfAnnotationPoint {
  const PdfAnnotationPoint({
    required this.page,
    required this.pdfX,
    required this.pdfY,
    required this.pageWidth,
    required this.pageHeight,
    this.rotation = 0,
  }) : assert(page >= 1);

  final int page;
  final double pdfX;
  final double pdfY;
  final double pageWidth;
  final double pageHeight;
  final int rotation;

  factory PdfAnnotationPoint.fromMetadata({
    required PdfPageMetadata metadata,
    required double pdfX,
    required double pdfY,
  }) {
    return PdfAnnotationPoint(
      page: metadata.pageNumber,
      pdfX: pdfX,
      pdfY: pdfY,
      pageWidth: metadata.width,
      pageHeight: metadata.height,
      rotation: metadata.rotation,
    );
  }

  /// Fraction within the stored page box (derived, not for persistence).
  double get fractionX =>
      pageWidth <= 0 ? 0 : (pdfX / pageWidth).clamp(0.0, 1.0);

  double get fractionY =>
      pageHeight <= 0 ? 0 : (pdfY / pageHeight).clamp(0.0, 1.0);

  double normalizedX(double width) =>
      (width <= 0 ? pageWidth : width) <= 0
      ? 0
      : (pdfX / (width <= 0 ? pageWidth : width)).clamp(0.0, 1.0);

  double normalizedY(double height) =>
      (height <= 0 ? pageHeight : height) <= 0
      ? 0
      : (pdfY / (height <= 0 ? pageHeight : height)).clamp(0.0, 1.0);

  /// API / persistence shape (PDF is source of truth).
  Map<String, dynamic> toJson() => {
    'page': page,
    'pdfX': pdfX,
    'pdfY': pdfY,
    'pdfWidth': pageWidth,
    'pdfHeight': pageHeight,
    'originalWidth': pageWidth,
    'originalHeight': pageHeight,
    if (rotation != 0) 'rotation': rotation,
  };

  factory PdfAnnotationPoint.fromJson(Map<String, dynamic> json) {
    final pageRaw = json['page'];
    final page = pageRaw is int
        ? pageRaw
        : (pageRaw is num ? pageRaw.toInt() : 1);
    final w =
        (json['pdfWidth'] as num?)?.toDouble() ??
        (json['originalWidth'] as num?)?.toDouble() ??
        (json['pageWidth'] as num?)?.toDouble() ??
        1.0;
    final h =
        (json['pdfHeight'] as num?)?.toDouble() ??
        (json['originalHeight'] as num?)?.toDouble() ??
        (json['pageHeight'] as num?)?.toDouble() ??
        1.0;
    return PdfAnnotationPoint(
      page: page < 1 ? 1 : page,
      pdfX: (json['pdfX'] as num?)?.toDouble() ?? 0,
      pdfY: (json['pdfY'] as num?)?.toDouble() ?? 0,
      pageWidth: w,
      pageHeight: h,
      rotation: (json['rotation'] as num?)?.toInt() ?? 0,
    );
  }

  PdfAnnotationPoint copyWith({
    int? page,
    double? pdfX,
    double? pdfY,
    double? pageWidth,
    double? pageHeight,
    int? rotation,
  }) {
    return PdfAnnotationPoint(
      page: page ?? this.page,
      pdfX: pdfX ?? this.pdfX,
      pdfY: pdfY ?? this.pdfY,
      pageWidth: pageWidth ?? this.pageWidth,
      pageHeight: pageHeight ?? this.pageHeight,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfAnnotationPoint &&
          page == other.page &&
          pdfX == other.pdfX &&
          pdfY == other.pdfY &&
          pageWidth == other.pageWidth &&
          pageHeight == other.pageHeight &&
          rotation == other.rotation;

  @override
  int get hashCode =>
      Object.hash(page, pdfX, pdfY, pageWidth, pageHeight, rotation);
}
