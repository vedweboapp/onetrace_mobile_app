import 'package:flutter/foundation.dart';

/// Device-independent pin position on a PDF page.
///
/// Stored as fractions of the page media box (0–1), not screen pixels.
/// Matches web payloads using `x_coordinate` / `y_coordinate` as 0–100.
@immutable
class PdfPageCoordinate {
  const PdfPageCoordinate({
    required this.page,
    required this.xPercent,
    required this.yPercent,
  }) : assert(page >= 1),
       assert(xPercent >= 0 && xPercent <= 1),
       assert(yPercent >= 0 && yPercent <= 1);

  /// 1-based page index (PDF convention).
  final int page;

  /// Horizontal position within the page rect, 0 = left, 1 = right.
  final double xPercent;

  /// Vertical position within the page rect, 0 = top, 1 = bottom.
  final double yPercent;

  /// Option B: build from PDF point space and original page dimensions.
  factory PdfPageCoordinate.fromPdfPoints({
    required int page,
    required double pdfX,
    required double pdfY,
    required double originalWidth,
    required double originalHeight,
  }) {
    final w = originalWidth <= 0 ? 1.0 : originalWidth;
    final h = originalHeight <= 0 ? 1.0 : originalHeight;
    return PdfPageCoordinate(
      page: page,
      xPercent: (pdfX / w).clamp(0.0, 1.0),
      yPercent: (pdfY / h).clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toJson() => {
    'page': page,
    'xPercent': xPercent,
    'yPercent': yPercent,
  };

  factory PdfPageCoordinate.fromJson(Map<String, dynamic> json) {
    final pageRaw = json['page'];
    final page = pageRaw is int
        ? pageRaw
        : (pageRaw is num ? pageRaw.toInt() : 1);
    return PdfPageCoordinate(
      page: page < 1 ? 1 : page,
      xPercent: _readFraction(json['xPercent'] ?? json['nx']),
      yPercent: _readFraction(json['yPercent'] ?? json['ny']),
    );
  }

  PdfPageCoordinate copyWith({
    int? page,
    double? xPercent,
    double? yPercent,
  }) {
    return PdfPageCoordinate(
      page: page ?? this.page,
      xPercent: xPercent ?? this.xPercent,
      yPercent: yPercent ?? this.yPercent,
    );
  }

  static double _readFraction(dynamic raw) {
    if (raw is num) {
      final v = raw.toDouble();
      return (v > 1 ? v / 100.0 : v).clamp(0.0, 1.0);
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPageCoordinate &&
          page == other.page &&
          xPercent == other.xPercent &&
          yPercent == other.yPercent;

  @override
  int get hashCode => Object.hash(page, xPercent, yPercent);
}
