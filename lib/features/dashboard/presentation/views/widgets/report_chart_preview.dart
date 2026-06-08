import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

enum ReportChartType {
  column,
  bar,
  line,
  pie,
}

extension ReportChartTypeX on ReportChartType {
  String get label => switch (this) {
        ReportChartType.column => 'Column Chart',
        ReportChartType.bar => 'Bar Chart',
        ReportChartType.line => 'Line Chart',
        ReportChartType.pie => 'Pie Chart',
      };

  static List<ReportChartType> get options => ReportChartType.values;
}

class ReportChartSeries {
  const ReportChartSeries({
    required this.labels,
    required this.values,
    this.color = const Color(0xFF3B82F6),
  });

  final List<String> labels;
  final List<double> values;
  final Color color;
}

class ReportChartPreview extends StatelessWidget {
  const ReportChartPreview({
    super.key,
    required this.series,
    required this.chartType,
    required this.onChartTypeChanged,
    this.title = 'Chart Preview',
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 0),
    this.showColorLegend = true,
  });

  final ReportChartSeries series;
  final ReportChartType chartType;
  final ValueChanged<ReportChartType> onChartTypeChanged;
  final String title;
  final EdgeInsetsGeometry margin;
  final bool showColorLegend;

  static const _border = Color(0xFFE8E8EA);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: title == 'PREVIEW' ? 13 : 16,
                  letterSpacing: title == 'PREVIEW' ? 0.8 : 0,
                ),
              ),
              const Spacer(),
              if (showColorLegend) ...[
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: series.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              _chartTypeDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _chartBody(),
          ),
        ],
      ),
    );
  }

  Widget _chartTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ReportChartType>(
          value: chartType,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: [
            for (final type in ReportChartTypeX.options)
              DropdownMenuItem(
                value: type,
                child: Text(type.label),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChartTypeChanged(value);
          },
        ),
      ),
    );
  }

  Widget _chartBody() {
    if (series.values.isEmpty || series.values.every((v) => v == 0)) {
      return Center(
        child: Text(
          'No chart data',
          style: AppFonts.bodyMedium(color: const Color(0xFF9CA3AF)),
        ),
      );
    }

    return switch (chartType) {
      ReportChartType.column => CustomPaint(
          painter: _ColumnChartPainter(series: series),
          child: const SizedBox.expand(),
        ),
      ReportChartType.bar => CustomPaint(
          painter: _BarChartPainter(series: series),
          child: const SizedBox.expand(),
        ),
      ReportChartType.line => CustomPaint(
          painter: _LineChartPainter(series: series),
          child: const SizedBox.expand(),
        ),
      ReportChartType.pie => CustomPaint(
          painter: _PieChartPainter(series: series),
          child: const SizedBox.expand(),
        ),
    };
  }
}

abstract final class _ChartPainterBase {
  static const gridColor = Color(0xFFE5E7EB);
  static const axisColor = Color(0xFF9CA3AF);

  static double maxY(List<double> values) {
    if (values.isEmpty) return 4;
    final maxVal = values.reduce(math.max);
    if (maxVal <= 4) return 4;
    return (maxVal.ceil() + 1).toDouble();
  }

  static void drawGrid(Canvas canvas, Size size, double maxY) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const leftPad = 28.0;
    const bottomPad = 28.0;
    const topPad = 8.0;
    final chartH = size.height - bottomPad - topPad;
    final chartW = size.width - leftPad - 8;

    for (var i = 0; i <= 4; i++) {
      final y = topPad + chartH - (chartH / 4) * i;
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + chartW, y), paint);
    }
  }

  static void drawYLabels(Canvas canvas, Size size, double maxY) {
    const leftPad = 28.0;
    const bottomPad = 28.0;
    const topPad = 8.0;
    final chartH = size.height - bottomPad - topPad;

    for (var i = 0; i <= 4; i++) {
      final value = (maxY / 4 * i).round();
      final y = topPad + chartH - (chartH / 4) * i;
      final tp = TextPainter(
        text: TextSpan(
          text: '$value',
          style: AppFonts.labelMedium(color: axisColor).copyWith(fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }
  }

  static void drawXLabels(
    Canvas canvas,
    Size size,
    List<String> labels,
    List<double> slotCenters,
  ) {
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: AppFonts.labelMedium(color: axisColor).copyWith(fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);
      tp.paint(
        canvas,
        Offset(slotCenters[i] - tp.width / 2, size.height - 22),
      );
    }
  }
}

class _ColumnChartPainter extends CustomPainter {
  _ColumnChartPainter({required this.series});

  final ReportChartSeries series;

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = _ChartPainterBase.maxY(series.values);
    _ChartPainterBase.drawGrid(canvas, size, maxY);
    _ChartPainterBase.drawYLabels(canvas, size, maxY);

    const leftPad = 28.0;
    const bottomPad = 28.0;
    const topPad = 8.0;
    final chartH = size.height - bottomPad - topPad;
    final chartW = size.width - leftPad - 8;
    final count = series.values.length;
    if (count == 0) return;

    final slotW = chartW / count;
    final barW = slotW * 0.42;
    final centers = <double>[];
    final fill = Paint()..color = series.color;

    for (var i = 0; i < count; i++) {
      final cx = leftPad + slotW * i + slotW / 2;
      centers.add(cx);
      final barH = (series.values[i] / maxY) * chartH;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, topPad + chartH - barH, barW, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, fill);
    }

    _ChartPainterBase.drawXLabels(canvas, size, series.labels, centers);
  }

  @override
  bool shouldRepaint(covariant _ColumnChartPainter oldDelegate) =>
      oldDelegate.series != series;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.series});

  final ReportChartSeries series;

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = _ChartPainterBase.maxY(series.values);
    const leftPad = 72.0;
    const rightPad = 12.0;
    const topPad = 8.0;
    const bottomPad = 12.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    final count = series.values.length;
    if (count == 0) return;

    final rowH = chartH / count;
    final barH = rowH * 0.5;
    final fill = Paint()..color = series.color;
    final grid = Paint()
      ..color = _ChartPainterBase.gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final x = leftPad + (chartW / 4) * i;
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + chartH),
        grid,
      );
    }

    for (var i = 0; i < count; i++) {
      final cy = topPad + rowH * i + rowH / 2;
      final labelTp = TextPainter(
        text: TextSpan(
          text: series.labels[i],
          style: AppFonts.labelMedium(color: _ChartPainterBase.axisColor)
              .copyWith(fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPad - 10);
      labelTp.paint(canvas, Offset(0, cy - labelTp.height / 2));

      final barW = (series.values[i] / maxY) * chartW;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftPad, cy - barH / 2, barW, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.series != series;
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.series});

  final ReportChartSeries series;

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = _ChartPainterBase.maxY(series.values);
    _ChartPainterBase.drawGrid(canvas, size, maxY);
    _ChartPainterBase.drawYLabels(canvas, size, maxY);

    const leftPad = 28.0;
    const bottomPad = 28.0;
    const topPad = 8.0;
    final chartH = size.height - bottomPad - topPad;
    final chartW = size.width - leftPad - 8;
    final count = series.values.length;
    if (count == 0) return;

    final slotW = chartW / count;
    final centers = <double>[];
    final points = <Offset>[];

    for (var i = 0; i < count; i++) {
      final cx = leftPad + slotW * i + slotW / 2;
      centers.add(cx);
      final y = topPad + chartH - (series.values[i] / maxY) * chartH;
      points.add(Offset(cx, y));
    }

    final linePaint = Paint()
      ..color = series.color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = series.color;
    final ring = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    for (final point in points) {
      canvas.drawCircle(point, 5, dotPaint);
      canvas.drawCircle(point, 2.5, ring);
    }

    _ChartPainterBase.drawXLabels(canvas, size, series.labels, centers);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.series != series;
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({required this.series});

  final ReportChartSeries series;
  static const _sliceColors = [
    Color(0xFF3B82F6),
    Color(0xFF60A5FA),
    Color(0xFF93C5FD),
    Color(0xFFBFDBFE),
    Color(0xFF1D4ED8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final total = series.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2 - 4);
    final radius = math.min(size.width, size.height) * 0.32;
    var startAngle = -math.pi / 2;

    for (var i = 0; i < series.values.length; i++) {
      final sweep = (series.values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = _sliceColors[i % _sliceColors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }

    for (var i = 0; i < series.labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${series.labels[i]} (${series.values[i].toInt()})',
          style: AppFonts.labelMedium(color: _ChartPainterBase.axisColor)
              .copyWith(fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width / 2);
      tp.paint(
        canvas,
        Offset(size.width / 2 + 8, 12 + i * 18.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.series != series;
}
