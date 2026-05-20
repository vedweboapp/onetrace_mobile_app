import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'pdf_annotation_point.dart';
import 'pdf_coordinate_engine.dart';

/// Renders pins at PDF-accurate positions; rebuilds on controller matrix changes.
class PdfPinOverlay extends StatefulWidget {
  const PdfPinOverlay({
    super.key,
    required this.controller,
    required this.engine,
    required this.pins,
    required this.pinBuilder,
    this.onPinTap,
  });

  final PdfControllerPinch controller;
  final PdfCoordinateEngine engine;
  final List<PdfAnnotationPoint> pins;

  /// Widget for each pin; receives viewport position center.
  final Widget Function(BuildContext context, int index, Offset viewportCenter)
  pinBuilder;

  final void Function(int index)? onPinTap;

  @override
  State<PdfPinOverlay> createState() => _PdfPinOverlayState();
}

class _PdfPinOverlayState extends State<PdfPinOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onViewportChanged);
  }

  @override
  void didUpdateWidget(covariant PdfPinOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onViewportChanged);
      widget.controller.addListener(_onViewportChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onViewportChanged);
    super.dispose();
  }

  void _onViewportChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.pins.length; i++)
          Builder(
            builder: (context) {
              final center =
                  widget.engine.annotationToViewport(widget.pins[i]);
              if (center == null) return const SizedBox.shrink();
              final child = widget.pinBuilder(context, i, center);
              if (widget.onPinTap == null) {
                return Positioned(left: center.dx, top: center.dy, child: child);
              }
              return Positioned(
                left: center.dx,
                top: center.dy,
                child: GestureDetector(
                  onTap: () => widget.onPinTap!(i),
                  behavior: HitTestBehavior.opaque,
                  child: child,
                ),
              );
            },
          ),
      ],
    );
  }
}
