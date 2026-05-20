import 'package:flutter/foundation.dart';

/// Immutable PDF page media-box metadata (source of truth for annotations).
@immutable
class PdfPageMetadata {
  const PdfPageMetadata({
    required this.pageNumber,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  /// 1-based page index.
  final int pageNumber;

  /// Page width in PDF user space (points, 1/72 inch).
  final double width;

  /// Page height in PDF user space (points).
  final double height;

  /// Clockwise rotation in degrees (0, 90, 180, 270).
  final int rotation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPageMetadata &&
          pageNumber == other.pageNumber &&
          width == other.width &&
          height == other.height &&
          rotation == other.rotation;

  @override
  int get hashCode => Object.hash(pageNumber, width, height, rotation);
}
