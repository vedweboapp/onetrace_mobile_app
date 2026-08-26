part of '../drawing_canvas.dart';

class PinView extends StatelessWidget {
  const PinView({
    super.key,
    required this.number,
    this.abbreviation,
    this.size = 32,
    this.pointerHeight = 9,
    this.selected = false,
    this.completed = false,
    this.statusBgColor,
    this.statusTextColor,
  });

  final int number;
  final String? abbreviation;
  final double size;
  final double pointerHeight;
  final bool selected;
  final bool completed;

  /// Pin-status catalog colors (`bg_colour` / `text_colour`) when available.
  final Color? statusBgColor;
  final Color? statusTextColor;

  @override
  Widget build(BuildContext context) {
    final abbr = abbreviation?.trim() ?? '';
    final topAbbr = abbr.isEmpty ? '' : abbr.toUpperCase();

    final statusAccent = statusBgColor;
    final statusFg = statusTextColor;
    final hasStatusColor = statusAccent != null;

    final Color borderColor;
    final Color fillColor;
    final Color textColor;
    final Color pointerColor;

    if (hasStatusColor) {
      // Status catalog colors take priority so pins match their status chips.
      borderColor = selected
          ? const Color(0xFF7C3AED)
          : Color.lerp(statusAccent, AppColors.inkStrong, 0.12)!;
      fillColor = statusAccent;
      textColor = statusFg ??
          (statusAccent.computeLuminance() > 0.55
              ? AppColors.inkStrong
              : AppColors.white);
      pointerColor = statusAccent;
    } else if (completed) {
      borderColor = const Color(0xFF0EA56A);
      fillColor = const Color(0xFFEFFAF4);
      textColor = const Color(0xFF0A8F5D);
      pointerColor = const Color(0xFF0EA56A);
    } else {
      borderColor = selected ? const Color(0xFF7C3AED) : AppColors.inkStrong;
      fillColor = AppColors.white;
      textColor = AppColors.inkStrong;
      pointerColor = AppColors.inkStrong;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size + pointerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fillColor,
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 3.4 : 3,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (topAbbr.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: size * 0.1),
                        child: Text(
                          topAbbr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.labelSmall(
                            color: textColor,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: size * 0.18,
                            height: 1.0,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    Text(
                      '$number',
                      style: AppFonts.labelMedium(
                        color: textColor,
                      ).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: size * 0.42,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: size / 2 - pointerHeight * 0.75,
                top: size - 1,
                child: CustomPaint(
                  size: Size(pointerHeight * 1.5, pointerHeight),
                  painter: _PinTrianglePainter(
                    fillColor: pointerColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  const _PinTrianglePainter({
    this.fillColor = const Color(0xFF111216),
  });

  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fillColor;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RegionLinePainter extends CustomPainter {
  const _RegionLinePainter({
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _RegionLinePainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _RegionShapePainter extends CustomPainter {
  const _RegionShapePainter({
    required this.path,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    this.dashPattern = const <double>[5, 4],
    this.crossCorners,
    this.crossColor,
    this.crossDashPattern = const <double>[4, 6],
  });

  final Path path;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final List<double> dashPattern;

  /// Polygon corners; dashed lines run from centroid to each corner.
  final List<Offset>? crossCorners;
  final Color? crossColor;
  final List<double> crossDashPattern;

  static Offset _polygonCentroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1) return points.first;
    if (points.length == 2) {
      return Offset(
        (points[0].dx + points[1].dx) / 2,
        (points[0].dy + points[1].dy) / 2,
      );
    }
    var twiceArea = 0.0;
    var cx = 0.0;
    var cy = 0.0;
    for (var i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      final cross = points[i].dx * points[j].dy - points[j].dx * points[i].dy;
      twiceArea += cross;
      cx += (points[i].dx + points[j].dx) * cross;
      cy += (points[i].dy + points[j].dy) * cross;
    }
    if (twiceArea.abs() < 1e-6) {
      var sx = 0.0;
      var sy = 0.0;
      for (final p in points) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / points.length, sy / points.length);
    }
    final area = twiceArea / 2;
    return Offset(cx / (6 * area), cy / (6 * area));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, fill);
    _paintDashedPath(canvas, path, stroke, dashPattern);

    final corners = crossCorners;
    final crossPaint = crossColor;
    if (corners != null && corners.length >= 2 && crossPaint != null) {
      final crossStroke = Paint()
        ..color = crossPaint
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final center = _polygonCentroid(corners);
      for (final corner in corners) {
        _paintDashedLine(canvas, center, corner, crossStroke, crossDashPattern);
      }
    }
  }

  static void _paintDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    List<double> dash,
  ) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    _paintDashedPath(canvas, path, paint, dash);
  }

  static void _paintDashedPath(
    Canvas canvas,
    Path source,
    Paint paint,
    List<double> dash,
  ) {
    if (dash.isEmpty) {
      canvas.drawPath(source, paint);
      return;
    }
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      var dashIndex = 0;
      while (distance < metric.length) {
        final segment = dash[dashIndex % dash.length];
        final end = (distance + segment).clamp(0.0, metric.length);
        if (draw && end > distance) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        draw = !draw;
        dashIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RegionShapePainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.dashPattern != dashPattern ||
        oldDelegate.crossCorners != crossCorners ||
        oldDelegate.crossColor != crossColor ||
        oldDelegate.crossDashPattern != crossDashPattern;
  }
}
