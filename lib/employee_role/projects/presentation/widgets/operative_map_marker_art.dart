import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Teardrop pins — inDrive / Rapido ride-app style.
abstract final class OperativeMapMarkerArt {
  OperativeMapMarkerArt._();

  /// Same pin art used on the route screen, as a Google Maps bitmap.
  static Future<BitmapDescriptor> bitmapTeardrop({
    required bool selected,
    double width = 44,
    double pixelRatio = 3,
  }) {
    final height = width * 1.23;
    return _paintToBitmap(
      size: Size(width, height),
      pixelRatio: pixelRatio,
      painter: _TeardropPinPainter(
        fill: selected ? const Color(0xFF111827) : Colors.white,
        stroke: selected ? const Color(0xFF22C55E) : const Color(0xFF111827),
        strokeWidth: selected ? 2.4 : 2,
        innerDot: selected ? Colors.white : const Color(0xFF111827),
      ),
    );
  }

  /// Circle site pin as a Google Maps bitmap.
  static Future<BitmapDescriptor> bitmapCircle({
    required bool selected,
    double size = 36,
    double pixelRatio = 3,
  }) {
    final dim = selected ? size + 4 : size;
    return _paintToBitmap(
      size: Size(dim, dim),
      pixelRatio: pixelRatio,
      painter: _CircleSitePinPainter(selected: selected, size: dim),
    );
  }

  /// User-location blue dot as a Google Maps bitmap.
  static Future<BitmapDescriptor> bitmapUserDot({
    double size = 18,
    double pixelRatio = 3,
  }) {
    final dim = size + 8;
    return _paintToBitmap(
      size: Size(dim, dim),
      pixelRatio: pixelRatio,
      painter: _UserDotPainter(size: size),
    );
  }

  static Future<BitmapDescriptor> _paintToBitmap({
    required Size size,
    required double pixelRatio,
    required CustomPainter painter,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (byteData == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  static Widget circleSitePin({
    required bool selected,
    double size = 36,
  }) {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: selected ? size + 4 : size,
        height: selected ? size + 4 : size,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF111827), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.location_on_rounded,
          color: selected ? Colors.white : const Color(0xFF111827),
          size: (selected ? size + 4 : size) * 0.48,
        ),
      ),
    );
  }

  /// Operative current location — Rapido-style blue dot.
  static Widget userLocationDot({double size = 18}) {
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 6,
            height: size + 6,
            decoration: BoxDecoration(
              color: const Color(0x335E4BFF),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF5E4BFF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget teardropPin({
    required bool selected,
    double width = 44,
  }) {
    final height = width * 1.23;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _TeardropPinPainter(
          fill: selected ? const Color(0xFF111827) : Colors.white,
          stroke: selected ? const Color(0xFF22C55E) : const Color(0xFF111827),
          strokeWidth: selected ? 2.4 : 2,
          innerDot: selected ? Colors.white : const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _TeardropPinPainter extends CustomPainter {
  const _TeardropPinPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.innerDot,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;
  final Color innerDot;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final bodyPaint = Paint()..color = fill;
    final borderPaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height * 0.35;
    final radius = size.width * 0.32;
    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    path.moveTo(cx - radius * 0.5, cy + radius * 0.64);
    path.lineTo(cx, size.height - 4);
    path.lineTo(cx + radius * 0.5, cy + radius * 0.64);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, borderPaint);
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.25,
      Paint()..color = innerDot,
    );
  }

  @override
  bool shouldRepaint(covariant _TeardropPinPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.innerDot != innerDot;
  }
}

class _CircleSitePinPainter extends CustomPainter {
  const _CircleSitePinPainter({
    required this.selected,
    required this.size,
  });

  final bool selected;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = size / 2;

    canvas.drawCircle(
      center.translate(0, 2),
      radius,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = selected ? const Color(0xFF111827) : Colors.white,
    );
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = const Color(0xFF111827)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final icon = Icons.location_on_rounded;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.48,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: selected ? Colors.white : const Color(0xFF111827),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _CircleSitePinPainter oldDelegate) {
    return oldDelegate.selected != selected || oldDelegate.size != size;
  }
}

class _UserDotPainter extends CustomPainter {
  const _UserDotPainter({required this.size});

  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    canvas.drawCircle(
      center,
      (size + 6) / 2,
      Paint()..color = const Color(0x335E4BFF),
    );
    canvas.drawCircle(
      center.translate(0, 1),
      size / 2,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      center,
      size / 2,
      Paint()..color = const Color(0xFF5E4BFF),
    );
    canvas.drawCircle(
      center,
      size / 2 - 1.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _UserDotPainter oldDelegate) {
    return oldDelegate.size != size;
  }
}
