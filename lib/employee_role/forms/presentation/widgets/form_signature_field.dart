import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/forms/data/signature_form_value.dart';

export 'package:red5/employee_role/forms/data/signature_form_value.dart';

/// Wins pan gestures over ancestor scrollables (e.g. [ListView]).
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({required super.debugOwner});

  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

/// Freehand digital signature pad for dynamic form fields.
class FormDigitalSignaturePad extends StatefulWidget {
  const FormDigitalSignaturePad({
    super.key,
    required this.strokes,
    required this.onChanged,
    this.readOnly = false,
    this.height = 160,
    this.onDrawingChanged,
  });

  final List<List<Offset>> strokes;
  final ValueChanged<List<List<Offset>>> onChanged;
  final ValueChanged<bool>? onDrawingChanged;
  final bool readOnly;
  final double height;

  @override
  State<FormDigitalSignaturePad> createState() => FormDigitalSignaturePadState();
}

class FormDigitalSignaturePadState extends State<FormDigitalSignaturePad> {
  final _repaintKey = GlobalKey();
  late List<List<Offset>> _strokes;
  List<Offset>? _activeStroke;
  bool _isDrawing = false;

  bool get hasSignature => _strokes.any((stroke) => stroke.length > 1);

  @override
  void initState() {
    super.initState();
    _strokes = _cloneStrokes(widget.strokes);
  }

  @override
  void didUpdateWidget(covariant FormDigitalSignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDrawing && oldWidget.strokes != widget.strokes) {
      _strokes = _cloneStrokes(widget.strokes);
    }
  }

  void clear() {
    if (widget.readOnly) return;
    setState(() {
      _strokes = const [];
      _activeStroke = null;
    });
    _commitToParent();
  }

  Future<Uint8List?> exportPng() async {
    if (!hasSignature) return null;
    final boundary = _repaintKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  void _setDrawing(bool value) {
    if (_isDrawing == value) return;
    _isDrawing = value;
    widget.onDrawingChanged?.call(value);
  }

  void _commitToParent() {
    widget.onChanged(_cloneStrokes(_strokes));
  }

  void _startStroke(Offset position) {
    if (widget.readOnly) return;
    _setDrawing(true);
    setState(() {
      _activeStroke = [position];
      _strokes = [..._strokes, _activeStroke!];
    });
  }

  void _extendStroke(Offset position) {
    if (widget.readOnly || _activeStroke == null) return;
    setState(() {
      _activeStroke!.add(position);
      final updated = List<List<Offset>>.from(_strokes);
      updated[updated.length - 1] = List<Offset>.from(_activeStroke!);
      _strokes = updated;
    });
  }

  void _endStroke() {
    if (!_isDrawing && _activeStroke == null) return;
    _activeStroke = null;
    _setDrawing(false);
    _commitToParent();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textFieldBorder,
                    width: 1.2,
                  ),
                ),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: <Type, GestureRecognizerFactory>{
                      _EagerPanGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                              _EagerPanGestureRecognizer>(
                        () => _EagerPanGestureRecognizer(debugOwner: this),
                        (_EagerPanGestureRecognizer instance) {
                          instance.onStart = (details) =>
                              _startStroke(details.localPosition);
                          instance.onUpdate = (details) =>
                              _extendStroke(details.localPosition);
                          instance.onEnd = (_) => _endStroke();
                          instance.onCancel = _endStroke;
                        },
                      ),
                    },
                    child: CustomPaint(
                      painter: _SignaturePainter(
                        strokes: _strokes,
                        showPlaceholder: !hasSignature,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            if (hasSignature && !widget.readOnly)
              Positioned(
                top: 8,
                right: 8,
                child: TextButton.icon(
                  onPressed: clear,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: const Color(0xFFF3F4F6),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'Clear',
                    style: AppFonts.labelSmall(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.readOnly
              ? 'Signature is read-only'
              : 'Draw your signature above',
          style: AppFonts.bodySmall(color: AppColors.muted),
        ),
      ],
    );
  }
}

List<List<Offset>> _cloneStrokes(List<List<Offset>> strokes) {
  return strokes
      .map((stroke) => List<Offset>.from(stroke))
      .toList(growable: false);
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({
    required this.strokes,
    required this.showPlaceholder,
  });

  final List<List<Offset>> strokes;
  final bool showPlaceholder;

  @override
  void paint(Canvas canvas, Size size) {
    final baselineY = size.height - 28;
    final baselinePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(16, baselineY),
      Offset(size.width - 16, baselineY),
      baselinePaint,
    );

    if (showPlaceholder) {
      final placeholder = TextPainter(
        text: TextSpan(
          text: 'Sign here...',
          style: AppFonts.bodyMedium(
            color: AppColors.textFieldHint,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 32);
      placeholder.paint(
        canvas,
        Offset(16, baselineY - placeholder.height - 8),
      );
    }

    final strokePaint = Paint()
      ..color = AppColors.inkStrong
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.inkStrong
      ..style = PaintingStyle.fill;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.2, dotPaint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.showPlaceholder != showPlaceholder;
  }
}
