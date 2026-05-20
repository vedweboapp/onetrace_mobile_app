import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'pdf_annotation_point.dart';
import 'pdf_coordinate_engine.dart';
import 'pdf_viewport_manager.dart';

/// Enterprise PDF canvas: viewer + matrix-aware pin overlay.
///
/// Pins are stored as [PdfAnnotationPoint] and reprojected on every zoom/pan.
class PdfAnnotationViewport extends StatefulWidget {
  const PdfAnnotationViewport({
    super.key,
    required this.manager,
    required this.pins,
    required this.pinBuilder,
    this.onPinTap,
    this.background,
    this.overlay,
    this.minScale = 0.5,
    this.maxScale = 8,
  });

  final PdfViewportManager manager;
  final List<PdfAnnotationPoint> pins;

  /// Receives viewport-local center for pin [index].
  final Widget Function(BuildContext context, int index, Offset viewportCenter)
  pinBuilder;

  final void Function(int index)? onPinTap;
  final Widget? background;
  final Widget? overlay;
  final double minScale;
  final double maxScale;

  @override
  State<PdfAnnotationViewport> createState() => _PdfAnnotationViewportState();
}

class _PdfAnnotationViewportState extends State<PdfAnnotationViewport> {
  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant PdfAnnotationViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) {
      oldWidget.manager.removeListener(_rebuild);
      widget.manager.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.manager.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.manager.controller;
    final engine = widget.manager.engine;
    if (ctrl == null) {
      return widget.background ?? const SizedBox.expand();
    }

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        PdfViewPinch(
          controller: ctrl,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
        ),
        if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
        if (engine != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: widget.onPinTap == null,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < widget.pins.length; i++)
                    Builder(
                      builder: (context) {
                        final center = engine.pdfToScreen(widget.pins[i]);
                        if (center == null) return const SizedBox.shrink();
                        final child = widget.pinBuilder(context, i, center);
                        if (widget.onPinTap == null) {
                          return Positioned(
                            left: center.dx,
                            top: center.dy,
                            child: child,
                          );
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
              ),
            ),
          ),
      ],
    );
  }
}
