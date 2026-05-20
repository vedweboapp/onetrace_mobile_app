import 'package:flutter/material.dart';

/// Decomposed mapping for one PDF page: user space → laid-out document rect.
///
/// Used to document the enterprise formula:
/// `screen = pdfPoint × scale + offset` (then apply global viewport matrix).
@immutable
class PdfPageTransform {
  const PdfPageTransform({
    required this.page,
    required this.pdfPageWidth,
    required this.pdfPageHeight,
    required this.layoutRect,
    required this.scaleX,
    required this.scaleY,
    required this.layoutOffset,
  });

  final int page;
  final double pdfPageWidth;
  final double pdfPageHeight;

  /// Page rectangle in pdfx **document/layout** space (before viewport matrix).
  final Rect layoutRect;
  final double scaleX;
  final double scaleY;
  final Offset layoutOffset;

  /// PDF user point → document/layout point (pre-viewport matrix).
  Offset pdfPointToDocument(double pdfX, double pdfY) {
    final w = pdfPageWidth <= 0 ? 1.0 : pdfPageWidth;
    final h = pdfPageHeight <= 0 ? 1.0 : pdfPageHeight;
    return Offset(
      layoutOffset.dx + (pdfX / w) * layoutRect.width,
      layoutOffset.dy + (pdfY / h) * layoutRect.height,
    );
  }

  /// Document point on this page → PDF user coordinates.
  Offset documentToPdfPoint(Offset document) {
    final w = layoutRect.width <= 0 ? 1.0 : layoutRect.width;
    final h = layoutRect.height <= 0 ? 1.0 : layoutRect.height;
    return Offset(
      ((document.dx - layoutOffset.dx) / w) * pdfPageWidth,
      ((document.dy - layoutOffset.dy) / h) * pdfPageHeight,
    );
  }
}
