import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Decomposed viewport transform from [PdfControllerPinch.value].
///
/// Enterprise viewers keep: screen = PDF × scale + offset (embedded in matrix).
@immutable
class PdfViewportState {
  const PdfViewportState({
    required this.matrix,
    required this.scale,
    required this.translation,
  });

  final Matrix4 matrix;
  final double scale;
  final Offset translation;

  factory PdfViewportState.fromController(PdfControllerPinch controller) {
    final m = controller.value;
    final scale = m.getMaxScaleOnAxis();
    final translation = Offset(m.getTranslation().x, m.getTranslation().y);
    return PdfViewportState(
      matrix: m.clone(),
      scale: scale,
      translation: translation,
    );
  }

  /// screen = pdfDocPoint transformed by [matrix] (pdfx document/layout space).
  Offset documentToViewport(Offset documentPoint) {
    return MatrixUtils.transformPoint(matrix, documentPoint);
  }

  /// Inverse: viewport-local → document/layout space.
  Offset viewportToDocument(Offset viewportLocal) {
    return MatrixUtils.transformPoint(Matrix4.inverted(matrix), viewportLocal);
  }
}
