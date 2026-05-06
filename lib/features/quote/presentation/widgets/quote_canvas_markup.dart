import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/theme/app_screen_size.dart';

import 'manage_plot_area_dialog.dart';
import 'pdf_markup_geometry.dart';

export 'pdf_markup_geometry.dart'
    show QuoteDocMarkup, PinEntry, BoxEntry, PolyEntry;

/// Tools for marking the quotation canvas (highlights, shapes, pins).
enum QuoteCanvasTool { select, pan, box, polygon, placePin }

/// Why a pin tap was rejected (parent may show a [SnackBar]).
enum QuotePinPlacementRejection {
  /// No box or polygon has been drawn yet.
  noAreaSelected,

  /// A highlight exists but the tap was outside it.
  outsideSelectedArea,

  /// Group and product must be chosen before pins are shown or placed.
  missingGroupOrProduct,

  /// Pin already exists too close to this location.
  overlapsExistingPin,
}

/// Enriches a geometry-only pin (coordinates) before it is stored.
typedef QuotePinMetadataBuilder =
    PinEntry Function(PinEntry geometry, String? containingPlotName);

/// Rename or delete an existing highlight (box / polygon) from Select mode.
typedef QuoteManagePlotAreaCallback =
    Future<PlotManageOutcome?> Function({
      required bool isBox,
      required int index,
      required String initialName,
    });

Rect _boundingNormRect(Iterable<Offset> pts) {
  double l = 1, t = 1, r = 0, b = 0;
  for (final o in pts) {
    l = o.dx < l ? o.dx : l;
    t = o.dy < t ? o.dy : t;
    r = o.dx > r ? o.dx : r;
    b = o.dy > b ? o.dy : b;
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// Paints highlights and polygons; pins use separate [QuoteMapPin] widgets.
class QuoteMarkupPainter extends CustomPainter {
  QuoteMarkupPainter({
    required this.markup,
    this.pdfController,
    this.isPdf = false,
    this.draftBox,
    this.draftPolygon,
    this.pulseT = 0,
    this.pulseBoxIndex,
    this.pulsePolyIndex,
  });

  final QuoteDocMarkup markup;
  final PdfControllerPinch? pdfController;
  final bool isPdf;
  final Rect? draftBox;
  final List<Offset>? draftPolygon;
  final double pulseT;
  final int? pulseBoxIndex;
  final int? pulsePolyIndex;

  static const _fill = AppColors.markupFill;
  static const _stroke = AppColors.markupStroke;
  static const _pulse = AppColors.markupStroke;

  /// Softer style for saved highlights.
  static const _fillCommitted = AppColors.markupFillCommitted;
  static const _strokeCommitted = AppColors.markupStrokeCommitted;

  void _drawViewportRect(
    Canvas canvas,
    Rect r, {
    bool pulse = false,
    bool committed = false,
    Color? color,
  }) {
    final base = color ?? _stroke;
    final fillColor = committed
        ? base.withValues(alpha: 0.12)
        : base.withValues(alpha: 0.20);
    final strokeColor = committed
        ? base.withValues(alpha: 0.62)
        : base.withValues(alpha: 1);
    final fill = Paint()..color = color == null ? (committed ? _fillCommitted : _fill) : fillColor;
    final stroke = Paint()
      ..color = color == null ? (committed ? _strokeCommitted : _stroke) : strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = committed ? 1.25 : 2;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(rr, stroke);

    if (pulse && pulseT > 0) {
      final expand = 6 * pulseT;
      final glow = RRect.fromRectAndRadius(
        r.inflate(expand),
        Radius.circular(4 + expand * 0.5),
      );
      canvas.drawRRect(
        glow,
        Paint()
          ..color = (color ?? _pulse).withValues(alpha: (1 - pulseT) * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawNormRect(Canvas canvas, Size size, Rect n, {bool pulse = false}) {
    final r = Rect.fromLTRB(
      n.left * size.width,
      n.top * size.height,
      n.right * size.width,
      n.bottom * size.height,
    );
    _drawViewportRect(canvas, r, pulse: pulse);
  }

  void _drawPolyLayerNorm(
    Canvas canvas,
    Size size,
    List<Offset> ptsN, {
    required bool closed,
    bool pulse = false,
  }) {
    if (ptsN.isEmpty) return;
    if (ptsN.length == 1) {
      final o = Offset(ptsN[0].dx * size.width, ptsN[0].dy * size.height);
      canvas.drawCircle(o, 5, Paint()..color = _stroke);
      return;
    }
    final path = Path();
    final first = Offset(ptsN[0].dx * size.width, ptsN[0].dy * size.height);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < ptsN.length; i++) {
      path.lineTo(ptsN[i].dx * size.width, ptsN[i].dy * size.height);
    }
    _strokePolyPath(
      canvas,
      path,
      closed: closed,
      pulse: pulse,
      size: size,
      ptsN: ptsN,
    );
  }

  void _strokePolyPath(
    Canvas canvas,
    Path path, {
    required bool closed,
    required bool pulse,
    required Size size,
    List<Offset>? ptsN,
    Rect? boundsFallback,
    bool committed = false,
    Color? color,
  }) {
    final base = color ?? _stroke;
    final fillC = color == null
        ? (committed ? _fillCommitted : _fill)
        : (committed
              ? base.withValues(alpha: 0.12)
              : base.withValues(alpha: 0.20));
    final strokeC = color == null
        ? (committed ? _strokeCommitted : _stroke)
        : (committed
              ? base.withValues(alpha: 0.62)
              : base.withValues(alpha: 1));
    final sw = committed ? 1.25 : 2.0;
    if (closed && path.computeMetrics().isNotEmpty) {
      path.close();
      canvas.drawPath(path, Paint()..color = fillC);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeC
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    if (pulse && closed && pulseT > 0) {
      Rect r;
      if (boundsFallback != null) {
        r = boundsFallback;
      } else if (ptsN != null && ptsN.length >= 3) {
        final n = _boundingNormRect(ptsN);
        r = Rect.fromLTRB(
          n.left * size.width,
          n.top * size.height,
          n.right * size.width,
          n.bottom * size.height,
        );
      } else {
        r = path.getBounds();
      }
      final expand = 6 * pulseT;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          r.inflate(expand),
          Radius.circular(4 + expand * 0.5),
        ),
        Paint()
          ..color = (color ?? _pulse).withValues(alpha: (1 - pulseT) * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawPlotLabel(Canvas canvas, Rect area, String text) {
    if (text.isEmpty) return;
    final display = text.toUpperCase();
    final maxW = (area.width * 0.92).clamp(40.0, 280.0);
    final tp = TextPainter(
      text: TextSpan(
        text: display,
        style: AppFonts.labelMedium(color: AppColors.ink).copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          backgroundColor: AppColors.markupTooltipBg,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW);
    final offset = Offset(
      area.center.dx - tp.width / 2,
      area.center.dy - tp.height / 2,
    );
    tp.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < markup.boxHighlights.length; i++) {
      final e = markup.boxHighlights[i];
      final pulse = pulseBoxIndex == i && pulseT > 0;
      final vr = boxEntryToViewportRect(e, pdfController, size, isPdf);
      if (vr != null) {
        _drawViewportRect(
          canvas,
          vr,
          pulse: pulse,
          committed: true,
          color: e.colorValue != null ? Color(e.colorValue!) : null,
        );
      }
    }
    if (draftBox != null) {
      _drawNormRect(canvas, size, draftBox!);
    }

    for (var i = 0; i < markup.polygons.length; i++) {
      final e = markup.polygons[i];
      final pulse = pulsePolyIndex == i && pulseT > 0;
      final path = polyEntryToViewportPath(e, pdfController, size, isPdf);
      if (path != null) {
        _strokePolyPath(
          canvas,
          path,
          closed: true,
          pulse: pulse,
          size: size,
          boundsFallback: path.getBounds(),
          committed: true,
          color: e.colorValue != null ? Color(e.colorValue!) : null,
        );
      }
    }
    if (draftPolygon != null && draftPolygon!.isNotEmpty) {
      _drawPolyLayerNorm(canvas, size, draftPolygon!, closed: false);
    }

    for (final e in markup.boxHighlights) {
      if (e.plotName.isEmpty) continue;
      final vr = boxEntryToViewportRect(e, pdfController, size, isPdf);
      if (vr != null) {
        _drawPlotLabel(canvas, vr, e.plotName);
      }
    }
    for (final e in markup.polygons) {
      if (e.plotName.isEmpty) continue;
      final path = polyEntryToViewportPath(e, pdfController, size, isPdf);
      if (path != null) {
        _drawPlotLabel(canvas, path.getBounds(), e.plotName);
      }
    }
  }

  @override
  bool shouldRepaint(covariant QuoteMarkupPainter oldDelegate) {
    return oldDelegate.markup != markup ||
        oldDelegate.pdfController != pdfController ||
        oldDelegate.isPdf != isPdf ||
        oldDelegate.draftBox != draftBox ||
        oldDelegate.draftPolygon != draftPolygon ||
        oldDelegate.pulseT != pulseT ||
        oldDelegate.pulseBoxIndex != pulseBoxIndex ||
        oldDelegate.pulsePolyIndex != pulsePolyIndex;
  }

  /// Default [CustomPainter.hitTest] is null → treated as hit everywhere, which
  /// blocks [PdfViewPinch] / [InteractiveViewer] underneath the overlay.
  @override
  bool? hitTest(Offset position) => false;
}

/// Material-style map pin with optional scale pulse ([pulseProgress] 0→1 from parent).
class QuoteMapPin extends StatelessWidget {
  const QuoteMapPin({super.key, required this.index, this.pulseProgress});

  final int index;

  /// When non-null, animates drop-in scale using elastic curve.
  final double? pulseProgress;

  @override
  Widget build(BuildContext context) {
    final t = pulseProgress;
    final scale = t == null
        ? 1.0
        : (0.42 + 0.58 * Curves.elasticOut.transform(t.clamp(0.0, 1.0)));

    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.brandPrimary,
                  size: 32,
                  shadows: [
                    Shadow(
                      color: AppColors.markupScrim,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: AppFonts.labelSmall(color: AppColors.brandPrimary)
                            .copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stacks [child], vector markup, pin widgets, and gestures.
class QuoteCanvasMarkupLayer extends StatefulWidget {
  const QuoteCanvasMarkupLayer({
    super.key,
    required this.tool,
    required this.markup,
    required this.onMarkupChanged,
    required this.child,
    this.pdfController,
    this.isPdf = false,
    this.onPinPlacementRejected,
    this.onPlotAreaNamed,
    this.showPinsOnCanvas = true,
    this.pinPrerequisitesMet = true,
    this.pinMetadataBuilder,
    this.onPinTapped,
    this.onManagePlotArea,
  });

  final QuoteCanvasTool tool;
  final QuoteDocMarkup markup;
  final VoidCallback onMarkupChanged;
  final Widget child;
  final PdfControllerPinch? pdfController;
  final bool isPdf;

  /// When false, existing pins are not drawn (e.g. until group + product are chosen).
  final bool showPinsOnCanvas;

  /// When false, [QuotePinPlacementRejection.missingGroupOrProduct] is reported on place-pin tap.
  final bool pinPrerequisitesMet;

  /// Merges coordinates with product / block metadata; if null, only geometry is stored.
  final QuotePinMetadataBuilder? pinMetadataBuilder;

  /// Called in [QuoteCanvasTool.select] when the user long-presses a pin
  /// (only if [showPinsOnCanvas]).
  final void Function(int index)? onPinTapped;

  /// When set, tapping a highlight in [QuoteCanvasTool.select] opens rename/delete flow.
  final QuoteManagePlotAreaCallback? onManagePlotArea;

  /// Called when pin mode is used without a valid highlight, or tap is outside highlights.
  final void Function(QuotePinPlacementRejection reason)?
  onPinPlacementRejected;

  /// After a box or polygon is committed; return name or `null` to discard the shape.
  final Future<String?> Function()? onPlotAreaNamed;

  @override
  State<QuoteCanvasMarkupLayer> createState() => _QuoteCanvasMarkupLayerState();
}

class _QuoteCanvasMarkupLayerState extends State<QuoteCanvasMarkupLayer>
    with SingleTickerProviderStateMixin {
  final GlobalKey _surfaceKey = GlobalKey();
  static const double _pinOverlapRadius = 30;
  static const List<Color> _highlightPalette = [
    AppColors.plotPinRose,
    AppColors.plotPinBlue,
    AppColors.plotPinGreen,
    AppColors.plotPinAmber,
    AppColors.plotPinViolet,
    AppColors.plotPinCyan,
  ];

  /// Matches [LayoutBuilder] / [CustomPaint] size (fixes unbounded [InteractiveViewer]).
  Size _overlaySize = Size.zero;

  Offset? _boxStartN;
  Rect? _draftBoxN;
  List<Offset>? _draftPolyN;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _pulse = CurvedAnimation(
    parent: _pulseController,
    curve: Curves.easeOutCubic,
  );

  int? _pulseBoxIndex;
  int? _pulsePolyIndex;
  int? _pulsePinIndex;
  int? _dragPinIndex;
  Offset? _dragPinLocal;
  bool _dragPinMoved = false;

  Color _nextHighlightColor() {
    final index =
        (widget.markup.boxHighlights.length + widget.markup.polygons.length) %
        _highlightPalette.length;
    return _highlightPalette[index];
  }

  Listenable get _markupListenable {
    final p = widget.pdfController;
    if (p != null) {
      return Listenable.merge([_pulseController, p]);
    }
    return _pulseController;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _clearDrafts() {
    _boxStartN = null;
    _draftBoxN = null;
    _draftPolyN = null;
  }

  Future<void> _applyPlotNameForBox(int index) async {
    final fn = widget.onPlotAreaNamed;
    if (fn == null) return;
    final name = await fn();
    if (!mounted) return;
    if (index < 0 || index >= widget.markup.boxHighlights.length) return;
    if (name == null) {
      widget.markup.boxHighlights.removeAt(index);
      widget.onMarkupChanged();
      setState(() {});
      return;
    }
    final e = widget.markup.boxHighlights[index];
    widget.markup.boxHighlights[index] = BoxEntry(
      n: e.n,
      page: e.page,
      plotName: name,
      colorValue: e.colorValue,
    );
    widget.onMarkupChanged();
    setState(() {});
  }

  Future<void> _applyPlotNameForPoly(int index) async {
    final fn = widget.onPlotAreaNamed;
    if (fn == null) return;
    final name = await fn();
    if (!mounted) return;
    if (index < 0 || index >= widget.markup.polygons.length) return;
    if (name == null) {
      widget.markup.polygons.removeAt(index);
      widget.onMarkupChanged();
      setState(() {});
      return;
    }
    final e = widget.markup.polygons[index];
    widget.markup.polygons[index] = PolyEntry(
      points: e.points,
      page: e.page,
      plotName: name,
      colorValue: e.colorValue,
    );
    widget.onMarkupChanged();
    setState(() {});
  }

  void _flashCommit({int? boxIndex, int? polyIndex, int? pinIndex}) {
    setState(() {
      _pulseBoxIndex = boxIndex;
      _pulsePolyIndex = polyIndex;
      _pulsePinIndex = pinIndex;
    });
    _pulseController.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() {
          _pulseBoxIndex = null;
          _pulsePolyIndex = null;
          _pulsePinIndex = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant QuoteCanvasMarkupLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool != widget.tool) {
      _clearDrafts();
    }
  }

  Offset _toNorm(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  Rect _normRect(Offset a, Offset b) {
    final left = a.dx < b.dx ? a.dx : b.dx;
    final top = a.dy < b.dy ? a.dy : b.dy;
    final right = a.dx > b.dx ? a.dx : b.dx;
    final bottom = a.dy > b.dy ? a.dy : b.dy;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  RenderBox? _surfaceRenderBox() {
    final keyed = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (keyed != null) return keyed;
    return context.findRenderObject() as RenderBox?;
  }

  /// Same basis as [CustomPaint] / [QuoteMarkupPainter] (avoids ∞ from unbounded parents).
  Size _basisSizeForNorm() {
    final box = _surfaceRenderBox();
    final rb = box?.size ?? Size.zero;
    if (_overlaySize.width > 0 && _overlaySize.height > 0) return _overlaySize;
    return rb;
  }

  bool _isOverlappingExistingPin(
    Offset local,
    Size viewport, {
    int? ignoreIndex,
  }) {
    for (var i = 0; i < widget.markup.pins.length; i++) {
      if (ignoreIndex != null && i == ignoreIndex) continue;
      final o = widget.markup.pins[i].toViewportOffset(
        widget.pdfController,
        viewport,
        widget.isPdf,
      );
      if (o == null) continue;
      if ((o - local).distance <= _pinOverlapRadius) return true;
    }
    return false;
  }

  int _indexOfPinNear(Offset local, Size viewport, {int? ignoreIndex}) {
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < widget.markup.pins.length; i++) {
      if (ignoreIndex != null && i == ignoreIndex) continue;
      final o = widget.markup.pins[i].toViewportOffset(
        widget.pdfController,
        viewport,
        widget.isPdf,
      );
      if (o == null) continue;
      final d = (o - local).distance;
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0 && bestDistance <= 28) return bestIndex;
    return -1;
  }

  PinEntry? _pinGeometryFromViewport(Offset local, Size viewport) {
    if (widget.isPdf && widget.pdfController != null) {
      return pdfPinFromViewportLocal(widget.pdfController!, local);
    }
    final n = _toNorm(local, viewport);
    return PinEntry(nx: n.dx, ny: n.dy);
  }

  void _beginPinLongPress(int index, Offset globalPosition) {
    final box = _surfaceRenderBox();
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalPosition);
    setState(() {
      _dragPinIndex = index;
      _dragPinLocal = local;
      _dragPinMoved = false;
    });
  }

  void _updatePinDrag(int index, Offset globalPosition) {
    if (_dragPinIndex != index) return;
    final box = _surfaceRenderBox();
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalPosition);
    setState(() {
      _dragPinMoved = true;
      _dragPinLocal = local;
    });
  }

  void _resetPinDrag() {
    if (!mounted) return;
    setState(() {
      _dragPinIndex = null;
      _dragPinLocal = null;
      _dragPinMoved = false;
    });
  }

  void _completePinLongPress(int index, Offset globalPosition) {
    final box = _surfaceRenderBox();
    final size = _basisSizeForNorm();
    if (box == null || !box.hasSize || index < 0 || index >= widget.markup.pins.length) {
      _resetPinDrag();
      return;
    }
    final local = box.globalToLocal(globalPosition);

    if (!_dragPinMoved) {
      _resetPinDrag();
      return;
    }

    if (!viewportPointInsideMarkupHighlights(
      local,
      size,
      widget.markup,
      widget.pdfController,
      widget.isPdf,
    )) {
      _resetPinDrag();
      widget.onPinPlacementRejected?.call(
        QuotePinPlacementRejection.outsideSelectedArea,
      );
      return;
    }

    if (_isOverlappingExistingPin(local, size, ignoreIndex: index)) {
      _resetPinDrag();
      widget.onPinPlacementRejected?.call(
        QuotePinPlacementRejection.overlapsExistingPin,
      );
      return;
    }

    final geo = _pinGeometryFromViewport(local, size);
    if (geo == null) {
      _resetPinDrag();
      return;
    }
    final old = widget.markup.pins[index];
    final plotName = plotNameForViewportPoint(
      local,
      size,
      widget.markup,
      widget.pdfController,
      widget.isPdf,
    );
    widget.markup.pins[index] = old.copyWith(
      nx: geo.nx,
      ny: geo.ny,
      page: geo.page,
      zoneLabel: (plotName ?? '').trim().isNotEmpty ? plotName!.trim() : old.zoneLabel,
    );
    widget.onMarkupChanged();
    _resetPinDrag();
  }

  void _onPlacePinPointerDown(PointerDownEvent e) {
    final box = _surfaceRenderBox();
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(e.position);
    final rbSize = box.size;
    final size = _overlaySize.width > 0 && _overlaySize.height > 0
        ? _overlaySize
        : rbSize;

    // Allow long-press interactions on existing pins while in place-pin mode.
    if (_indexOfPinNear(local, size) >= 0) {
      return;
    }

    if (!widget.pinPrerequisitesMet) {
      widget.onPinPlacementRejected?.call(
        QuotePinPlacementRejection.missingGroupOrProduct,
      );
      return;
    }

    final hasHighlight =
        widget.markup.boxHighlights.isNotEmpty ||
        widget.markup.polygons.isNotEmpty;
    if (!hasHighlight) {
      widget.onPinPlacementRejected?.call(
        QuotePinPlacementRejection.noAreaSelected,
      );
      return;
    }
    if (!viewportPointInsideMarkupHighlights(
      local,
      size,
      widget.markup,
      widget.pdfController,
      widget.isPdf,
    )) {
      widget.onPinPlacementRejected?.call(
        QuotePinPlacementRejection.outsideSelectedArea,
      );
      return;
    }

    final plotName = plotNameForViewportPoint(
      local,
      size,
      widget.markup,
      widget.pdfController,
      widget.isPdf,
    );

    if (_isOverlappingExistingPin(local, size)) {
      widget.onPinPlacementRejected?.call(
        QuotePinPlacementRejection.overlapsExistingPin,
      );
      return;
    }

    if (widget.isPdf && widget.pdfController != null) {
      final geo = pdfPinFromViewportLocal(widget.pdfController!, local);
      if (geo != null) {
        final pin = widget.pinMetadataBuilder?.call(geo, plotName) ?? geo;
        widget.markup.pins.add(pin);
        widget.onMarkupChanged();
        final idx = widget.markup.pins.length - 1;
        setState(() {});
        _flashCommit(pinIndex: idx);
      }
      return;
    }

    final n = _toNorm(local, size);
    final geo = PinEntry(nx: n.dx, ny: n.dy);
    final pin = widget.pinMetadataBuilder?.call(geo, plotName) ?? geo;
    widget.markup.pins.add(pin);
    widget.onMarkupChanged();
    final idx = widget.markup.pins.length - 1;
    setState(() {});
    _flashCommit(pinIndex: idx);
  }

  void _retargetPinsPlotName(String oldName, String newName) {
    final o = oldName.trim();
    final n = newName.trim();
    if (o.isEmpty || o == n) return;
    for (var i = 0; i < widget.markup.pins.length; i++) {
      final pin = widget.markup.pins[i];
      if ((pin.zoneLabel ?? '').trim() == o) {
        widget.markup.pins[i] = pin.copyWith(zoneLabel: n);
      }
    }
  }

  /// Removes pins whose zone matches this plot (used when plot is deleted).
  void _removePinsAssignedToPlot(String plotName) {
    final t = plotName.trim();
    if (t.isEmpty) return;
    widget.markup.pins.removeWhere(
      (pin) => (pin.zoneLabel ?? '').trim() == t,
    );
  }

  Future<void> _handleManagePlotTap(PlotHighlightHit hit) async {
    final fn = widget.onManagePlotArea;
    if (fn == null) return;

    String initialName;
    if (hit.isBox) {
      if (hit.index < 0 || hit.index >= widget.markup.boxHighlights.length) {
        return;
      }
      initialName = widget.markup.boxHighlights[hit.index].plotName;
    } else {
      if (hit.index < 0 || hit.index >= widget.markup.polygons.length) return;
      initialName = widget.markup.polygons[hit.index].plotName;
    }

    final outcome = await fn(
      isBox: hit.isBox,
      index: hit.index,
      initialName: initialName,
    );
    if (!mounted || outcome == null) return;

    if (outcome.delete) {
      final oldName = initialName;
      if (hit.isBox) {
        if (hit.index < widget.markup.boxHighlights.length) {
          widget.markup.boxHighlights.removeAt(hit.index);
        }
      } else {
        if (hit.index < widget.markup.polygons.length) {
          widget.markup.polygons.removeAt(hit.index);
        }
      }
      _removePinsAssignedToPlot(oldName);
      widget.onMarkupChanged();
      setState(() {});
      return;
    }

    if (!outcome.isSaved) return;
    final newName = outcome.savedName!;

    if (hit.isBox) {
      if (hit.index >= widget.markup.boxHighlights.length) return;
      final e = widget.markup.boxHighlights[hit.index];
      final old = e.plotName;
      widget.markup.boxHighlights[hit.index] = BoxEntry(
        n: e.n,
        page: e.page,
        plotName: newName,
        colorValue: e.colorValue,
      );
      _retargetPinsPlotName(old, newName);
    } else {
      if (hit.index >= widget.markup.polygons.length) return;
      final e = widget.markup.polygons[hit.index];
      final old = e.plotName;
      widget.markup.polygons[hit.index] = PolyEntry(
        points: e.points,
        page: e.page,
        plotName: newName,
        colorValue: e.colorValue,
      );
      _retargetPinsPlotName(old, newName);
    }
    widget.onMarkupChanged();
    setState(() {});
  }

  void _tryOpenPlotEditorFromGlobal(Offset globalPosition) {
    if (widget.tool != QuoteCanvasTool.select ||
        widget.onManagePlotArea == null) {
      return;
    }
    final box = _surfaceRenderBox();
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalPosition);
    final size = _overlaySize.width > 0 && _overlaySize.height > 0
        ? _overlaySize
        : box.size;

    if (_indexOfPinNear(local, size) >= 0) return;

    final hit = findTopPlotHighlightAt(
      local,
      size,
      widget.markup,
      widget.pdfController,
      widget.isPdf,
    );
    if (hit == null) return;
    unawaited(_handleManagePlotTap(hit));
  }

  /// Long-press on a highlight (not on a pin) opens Edit Plot. Single taps
  /// pass through to the PDF / image viewer underneath.
  void _onSelectPlotLongPressStart(LongPressStartDetails d) {
    _tryOpenPlotEditorFromGlobal(d.globalPosition);
  }

  void _onSelectPlotDoubleTapDown(TapDownDetails d) {
    _tryOpenPlotEditorFromGlobal(d.globalPosition);
  }

  void _onOverlayTapUp(TapUpDetails d) {
    if (widget.tool == QuoteCanvasTool.polygon) {
      final box = _surfaceRenderBox();
      if (box == null) return;
      final size = _basisSizeForNorm();
      final local = box.globalToLocal(d.globalPosition);
      final n = _toNorm(local, size);
      _draftPolyN ??= [];
      _draftPolyN!.add(n);
      setState(() {});
      return;
    }

    if (widget.tool != QuoteCanvasTool.select ||
        !widget.showPinsOnCanvas ||
        widget.onPinTapped == null ||
        widget.markup.pins.isEmpty) {
      return;
    }

    final box = _surfaceRenderBox();
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(d.globalPosition);
    final size = _overlaySize.width > 0 && _overlaySize.height > 0
        ? _overlaySize
        : box.size;

    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < widget.markup.pins.length; i++) {
      final o = widget.markup.pins[i].toViewportOffset(
        widget.pdfController,
        size,
        widget.isPdf,
      );
      if (o == null) continue;
      final anchor = Offset(o.dx, o.dy - 8);
      final dist = (anchor - local).distance;
      if (dist < bestDistance) {
        bestDistance = dist;
        bestIndex = i;
      }
    }

    if (bestIndex >= 0 && bestDistance <= 28) {
      widget.onPinTapped!(bestIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = AppScreenSize.sizeOf(context);
        var w = constraints.maxWidth;
        var h = constraints.maxHeight;
        if (!w.isFinite || w <= 0) w = screen.width;
        if (!h.isFinite || h <= 0) h = screen.height;
        final overlaySize = Size(w, h);
        _overlaySize = overlaySize;

        /// Keep overlay interactive so pins can always be edited on tap.
        /// Non-pin areas still pass through to underlying viewer.
        const passPointerToViewer = false;

        return IgnorePointer(
          ignoring: passPointerToViewer,
          child: AnimatedBuilder(
            animation: _markupListenable,
            builder: (context, _) {
              return Stack(
                fit: StackFit.passthrough,
                alignment: Alignment.center,
                children: [
                  widget.child,
                  Positioned.fill(
                    child: CustomPaint(
                      painter: QuoteMarkupPainter(
                        markup: widget.markup,
                        pdfController: widget.pdfController,
                        isPdf: widget.isPdf,
                        draftBox: _draftBoxN,
                        draftPolygon: _draftPolyN,
                        pulseT: _pulseController.isAnimating ? _pulse.value : 0,
                        pulseBoxIndex: _pulseBoxIndex,
                        pulsePolyIndex: _pulsePolyIndex,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: widget.tool == QuoteCanvasTool.pan,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          if (widget.tool == QuoteCanvasTool.select &&
                              widget.onManagePlotArea != null)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onLongPressStart: _onSelectPlotLongPressStart,
                                onDoubleTapDown: _onSelectPlotDoubleTapDown,
                              ),
                            ),
                          if (widget.showPinsOnCanvas)
                            ...List<Widget>.generate(
                              widget.markup.pins.length,
                              (i) {
                                final o = widget.markup.pins[i].toViewportOffset(
                                  widget.pdfController,
                                  overlaySize,
                                  widget.isPdf,
                                );
                                if (o == null) return const SizedBox.shrink();
                                final isDragging = _dragPinIndex == i;
                                final pinLocal = isDragging && _dragPinLocal != null
                                    ? _dragPinLocal!
                                    : o;
                                final pinChild = QuoteMapPin(
                                  index: i,
                                  pulseProgress:
                                      _pulsePinIndex == i &&
                                          _pulseController.isAnimating
                                      ? _pulse.value
                                      : null,
                                );
                                final tappable = widget.onPinTapped != null;
                                return Positioned(
                                  left: pinLocal.dx - 18,
                                  top: pinLocal.dy - 40,
                                  child: tappable
                                      ? Material(
                                          color: Colors.transparent,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => widget.onPinTapped!(i),
                                            onLongPressStart: (details) =>
                                                _beginPinLongPress(
                                                  i,
                                                  details.globalPosition,
                                                ),
                                            onLongPressMoveUpdate: (details) =>
                                                _updatePinDrag(
                                                  i,
                                                  details.globalPosition,
                                                ),
                                            onLongPressEnd: (details) =>
                                                _completePinLongPress(
                                                  i,
                                                  details.globalPosition,
                                                ),
                                            onLongPressCancel: _resetPinDrag,
                                            child: Opacity(
                                              opacity: isDragging ? 0.9 : 1,
                                              child: pinChild,
                                            ),
                                          ),
                                        )
                                      : pinChild,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.tool != QuoteCanvasTool.pan &&
                      widget.tool != QuoteCanvasTool.select)
                    if (widget.tool == QuoteCanvasTool.placePin)
                      Positioned.fill(
                        child: Listener(
                          key: _surfaceKey,
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: _onPlacePinPointerDown,
                          child: const SizedBox.expand(),
                        ),
                      )
                    else
                      Positioned.fill(
                        child: GestureDetector(
                          key: _surfaceKey,
                          behavior: HitTestBehavior.opaque,
                          onPanStart: widget.tool == QuoteCanvasTool.box
                              ? (details) {
                                  final box = _surfaceRenderBox();
                                  if (box == null) return;
                                  final size = _basisSizeForNorm();
                                  final local = box.globalToLocal(
                                    details.globalPosition,
                                  );
                                  _boxStartN = _toNorm(local, size);
                                  _draftBoxN = null;
                                  setState(() {});
                                }
                              : null,
                          onPanUpdate: widget.tool == QuoteCanvasTool.box
                              ? (details) {
                                  final box = _surfaceRenderBox();
                                  final size = _basisSizeForNorm();
                                  final start = _boxStartN;
                                  if (box == null || start == null) return;
                                  final local = box.globalToLocal(
                                    details.globalPosition,
                                  );
                                  final cur = _toNorm(local, size);
                                  setState(() {
                                    _draftBoxN = _normRect(start, cur);
                                  });
                                }
                              : null,
                          onPanEnd: widget.tool == QuoteCanvasTool.box
                              ? (_) {
                                  final r = _draftBoxN;
                                  _boxStartN = null;
                                  if (r != null) {
                                    final width = r.width;
                                    final height = r.height;
                                    if (width > 0.008 && height > 0.008) {
                                      if (widget.isPdf &&
                                          widget.pdfController != null) {
                                        final committed = pdfCommitLayerNormBox(
                                          widget.pdfController!,
                                          r,
                                          _basisSizeForNorm(),
                                        );
                                        if (committed != null) {
                                          final color = _nextHighlightColor();
                                          widget.markup.boxHighlights.add(
                                            BoxEntry(
                                              n: committed.n,
                                              page: committed.page,
                                              plotName: committed.plotName,
                                              colorValue: color.toARGB32(),
                                            ),
                                          );
                                          final bi =
                                              widget
                                                  .markup
                                                  .boxHighlights
                                                  .length -
                                              1;
                                          widget.onMarkupChanged();
                                          _flashCommit(boxIndex: bi);
                                          unawaited(_applyPlotNameForBox(bi));
                                        }
                                      } else {
                                        final color = _nextHighlightColor();
                                        widget.markup.boxHighlights.add(
                                          BoxEntry(
                                            n: r,
                                            colorValue: color.toARGB32(),
                                          ),
                                        );
                                        final bi =
                                            widget.markup.boxHighlights.length -
                                            1;
                                        widget.onMarkupChanged();
                                        _flashCommit(boxIndex: bi);
                                        unawaited(_applyPlotNameForBox(bi));
                                      }
                                    }
                                  }
                                  _draftBoxN = null;
                                  setState(() {});
                                }
                              : null,
                          onTapUp: _onOverlayTapUp,
                          onDoubleTap: widget.tool == QuoteCanvasTool.polygon
                              ? () {
                                  final pts = _draftPolyN;
                                  if (pts == null || pts.length < 3) {
                                    _draftPolyN = null;
                                    setState(() {});
                                    return;
                                  }
                                  final vp = _basisSizeForNorm();
                                  if (widget.isPdf &&
                                      widget.pdfController != null) {
                                    final committed = pdfCommitLayerNormPoly(
                                      widget.pdfController!,
                                      List<Offset>.from(pts),
                                      vp,
                                    );
                                    if (committed != null) {
                                      final color = _nextHighlightColor();
                                      widget.markup.polygons.add(committed);
                                      final i = widget.markup.polygons.length - 1;
                                      final current = widget.markup.polygons[i];
                                      widget.markup.polygons[i] = PolyEntry(
                                        points: current.points,
                                        page: current.page,
                                        plotName: current.plotName,
                                        colorValue: color.toARGB32(),
                                      );
                                      final pi =
                                          widget.markup.polygons.length - 1;
                                      _draftPolyN = null;
                                      widget.onMarkupChanged();
                                      setState(() {});
                                      _flashCommit(polyIndex: pi);
                                      unawaited(_applyPlotNameForPoly(pi));
                                    } else {
                                      _draftPolyN = null;
                                      setState(() {});
                                    }
                                  } else {
                                    final color = _nextHighlightColor();
                                    widget.markup.polygons.add(
                                      PolyEntry(
                                        points: List<Offset>.from(pts),
                                        colorValue: color.toARGB32(),
                                      ),
                                    );
                                    final pi =
                                        widget.markup.polygons.length - 1;
                                    _draftPolyN = null;
                                    widget.onMarkupChanged();
                                    setState(() {});
                                    _flashCommit(polyIndex: pi);
                                    unawaited(_applyPlotNameForPoly(pi));
                                  }
                                }
                              : null,
                        ),
                      ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
