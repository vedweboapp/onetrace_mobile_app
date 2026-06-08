import 'pdf_annotation_point.dart';
import 'pdf_coordinate_engine.dart';
import 'pdf_page_coordinate.dart';
import 'pdf_page_metadata.dart';
import 'pdf_page_metadata_cache.dart';

/// Encodes/decodes annotation positions for REST payloads shared with the website.
class PdfCoordinateCodec {
  const PdfCoordinateCodec._();

  /// Legacy normalized model (0–1). Prefer [PdfAnnotationPoint] + [PdfCoordinateEngine].
  static PdfPageCoordinate? pageCoordinateFromApi({
    required dynamic xRaw,
    required dynamic yRaw,
    int page = 1,
  }) {
    final x = _toDouble(xRaw);
    final y = _toDouble(yRaw);
    if (x == null || y == null) return null;
    return PdfPageCoordinate(
      page: page < 1 ? 1 : page,
      xPercent: _normalizeApiScalar(x),
      yPercent: _normalizeApiScalar(y),
    );
  }

  /// True PDF-space point from API (percent → pdfX/pdfY when metadata available).
  static PdfAnnotationPoint? annotationFromApi({
    required dynamic xRaw,
    required dynamic yRaw,
    int page = 1,
    PdfPageMetadata? metadata,
    PdfPageMetadataCache? cache,
  }) {
    final meta = metadata ?? cache?.page(page);
    if (meta == null) {
      final nx = _normalizeApiScalar(_toDouble(xRaw) ?? 0);
      final ny = _normalizeApiScalar(_toDouble(yRaw) ?? 0);
      return PdfAnnotationPoint(
        page: page,
        pdfX: nx,
        pdfY: ny,
        pageWidth: 1,
        pageHeight: 1,
      );
    }
    final x = _toDouble(xRaw);
    final y = _toDouble(yRaw);
    if (x == null || y == null) return null;
    if (x > 1 || y > 1 || (x <= 1 && y <= 1 && x <= 1.001)) {
      final nx = _normalizeApiScalar(x);
      final ny = _normalizeApiScalar(y);
      return PdfAnnotationPoint.fromMetadata(
        metadata: meta,
        pdfX: nx * meta.width,
        pdfY: ny * meta.height,
      );
    }
    return PdfAnnotationPoint.fromMetadata(
      metadata: meta,
      pdfX: x,
      pdfY: y,
    );
  }

  static Map<String, dynamic> annotationToApi(
    PdfAnnotationPoint point, {
    bool asPercentage = true,
  }) {
    if (asPercentage) {
      final w = point.pageWidth > 0 ? point.pageWidth : 1.0;
      final h = point.pageHeight > 0 ? point.pageHeight : 1.0;
      return {
        'page': point.page,
        'x_coordinate': ((point.pdfX / w) * 100).round(),
        'y_coordinate': ((point.pdfY / h) * 100).round(),
      };
    }
    return {
      'page': point.page,
      'x_coordinate': point.pdfX,
      'y_coordinate': point.pdfY,
      'originalWidth': point.pageWidth,
      'originalHeight': point.pageHeight,
    };
  }

  static Map<String, dynamic> pageCoordinateToApi(
    PdfPageCoordinate coord, {
    bool asPercentage = true,
  }) {
    if (asPercentage) {
      return {
        'x_coordinate': (coord.xPercent * 100).round(),
        'y_coordinate': (coord.yPercent * 100).round(),
      };
    }
    return {
      'x_coordinate': coord.xPercent,
      'y_coordinate': coord.yPercent,
    };
  }

  /// Converts API `x_coordinate` / `y_coordinate` (0–1 or 0–100) to 0–1 fraction.
  static double normalizeApiScalar(double value) =>
      (value > 1 ? value / 100.0 : value).clamp(0.0, 1.0);

  static double _normalizeApiScalar(double value) => normalizeApiScalar(value);

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }
}
