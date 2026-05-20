import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/pdf_coordinates/pdf_coordinates.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Route payload for [DrawingCanvasPage]. Use [toExtra] with GoRouter and
/// [DrawingCanvasPage.push] so every entry point matches [AppRouter] parsing.
@immutable
class DrawingCanvasArgs {
  const DrawingCanvasArgs({
    required this.title,
    this.filePath,
    this.remoteDrawingUrl,
    this.levelName,
    this.projectName,
    this.projectId,
    this.levelId,
  });

  final String title;
  final String? filePath;

  /// Absolute URL or API path; passed to the route as `drawingUrl`.
  final String? remoteDrawingUrl;
  final String? levelName;
  final String? projectName;
  final String? projectId;
  final String? levelId;

  Map<String, dynamic> toExtra() {
    final t = title.trim();
    final fp = (filePath ?? '').trim();
    final url = (remoteDrawingUrl ?? '').trim();
    final ln = (levelName ?? '').trim();
    final pn = (projectName ?? '').trim();
    final pid = (projectId ?? '').trim();
    final lid = (levelId ?? '').trim();
    return <String, dynamic>{
      if (t.isNotEmpty) 'title': t,
      if (fp.isNotEmpty) 'filePath': fp,
      if (url.isNotEmpty) 'drawingUrl': url,
      if (ln.isNotEmpty) 'levelName': ln,
      if (pn.isNotEmpty) 'projectName': pn,
      if (pid.isNotEmpty) 'projectId': pid,
      if (lid.isNotEmpty) 'levelId': lid,
    };
  }

  /// Same field mapping used after [UploadDrawingPage] returns a result map.
  factory DrawingCanvasArgs.fromUploadResult(
    Map<String, dynamic> map, {
    required String projectName,
    required String projectId,
  }) {
    final fileName = (map['fileName'] ?? '').toString().trim();
    final pdfName = (map['pdfName'] ?? '').toString().trim();
    final filePath = (map['filePath'] ?? '').toString().trim();
    final levelName = (map['levelName'] ?? '').toString().trim();
    final uploadedProjectId = (map['projectId'] ?? '').toString().trim();
    final levelId = (map['levelId'] ?? '').toString().trim();
    final title = (pdfName.isNotEmpty ? pdfName : fileName).trim();
    final resolvedPid = uploadedProjectId.isEmpty
        ? projectId.trim()
        : uploadedProjectId;
    return DrawingCanvasArgs(
      title: title,
      filePath: filePath.isEmpty ? null : filePath,
      levelName: levelName.isEmpty ? null : levelName,
      projectName: projectName.trim().isEmpty ? null : projectName.trim(),
      projectId: resolvedPid.isEmpty ? null : resolvedPid,
      levelId: levelId.isEmpty ? null : levelId,
    );
  }

  static int uploadCountFromResult(Map<String, dynamic> map) {
    final uploadCount = map['uploadCount'] is int
        ? (map['uploadCount'] as int).clamp(1, 999)
        : (((map['filePath'] ?? '').toString().trim().isNotEmpty) ? 1 : 0);
    return uploadCount;
  }
}

class DrawingCanvasPage extends ConsumerStatefulWidget {
  const DrawingCanvasPage({
    super.key,
    required this.title,
    this.filePath,
    this.remoteDrawingUrl,
    this.levelName,
    this.projectName,
    this.projectId,
    this.levelId,
  });

  static const path = '/drawing-canvas';
  static const name = 'drawing-canvas';

  /// Opens the canvas with the same `extra` shape the router expects everywhere.
  static Future<bool?> push(BuildContext context, DrawingCanvasArgs args) {
    return context.push<bool>(path, extra: args.toExtra());
  }

  final String title;
  final String? filePath;

  /// Absolute URL or API path (e.g. `/backend/media/...`) when [filePath] is not available locally.
  final String? remoteDrawingUrl;
  final String? levelName;
  final String? projectName;
  final String? projectId;
  final String? levelId;

  @override
  ConsumerState<DrawingCanvasPage> createState() => _DrawingCanvasPageState();
}

class _DrawingCanvasPageState extends ConsumerState<DrawingCanvasPage> {
  final TextEditingController _blockController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  List<GroupItemOption> _groupOptions = const <GroupItemOption>[];
  List<CompositeItemOption> _productOptions = const <CompositeItemOption>[];
  int? _selectedGroupId;
  int? _selectedCompositeItemId;

  /// Default for new pins; toggled on the drawing form before placing a pin.
  bool _variationOn = false;
  bool _isLoadingGroups = false;
  bool _isLoadingCompositeItems = false;
  static const List<Color> _regionBorderColors = <Color>[
    Color(0xFF1E7DD8), // blue
    Color(0xFFF97316), // orange
    Color(0xFFA855F7), // purple
    Color(0xFF22C55E), // green
    Color(0xFFEC4899), // pink
    Color(0xFFF59E0B), // amber
    Color(0xFF06B6D4), // cyan
    Color(0xFFEF4444), // red
  ];

  static const double _regionBorderWidth = 1.0;
  static const List<double> _regionDashPattern = <double>[5, 4];
  static const List<double> _regionCrossDashPattern = <double>[4, 6];

  Color _regionFillColor(int index) =>
      _regionBorderColors[index % _regionBorderColors.length].withValues(
        alpha: 0.16,
      );

  Color _regionBorderColor(int index) =>
      _regionBorderColors[index % _regionBorderColors.length];
  PdfControllerPinch? _pdfController;
  PdfPageMetadataCache? _pdfMetadataCache;

  PdfCoordinateEngine? get _pdfEngine {
    final ctrl = _pdfController;
    final meta = _pdfMetadataCache;
    if (ctrl == null || meta == null) return null;
    return PdfCoordinateEngine(controller: ctrl, metadata: meta);
  }
  String? _activeFilePath;
  final List<String> _uploadedPdfPaths = <String>[];
  final Map<String, List<_PlotRegion>> _regionsByPdfPath = {};
  final Map<String, List<_CanvasLine>> _linesByPdfPath = {};
  final List<_CanvasLine> _canvasLines = <_CanvasLine>[];
  final TransformationController _viewerTransform = TransformationController();
  _CanvasTool? _selectedTool = _CanvasTool.share;
  bool _isSelectAllEnabled = false;
  final List<_PlotRegion> _regions = <_PlotRegion>[];
  int? _activeRegionIndex;
  Offset? _draftStart;
  Offset? _draftCurrent;
  final List<Offset> _lineDraftPoints = <Offset>[];
  Offset? _lineDraftCurrent;
  int? _movingRegionIndex;
  Offset? _regionMoveAnchorScene;
  int? _regionPressIndex;
  Offset? _regionPressScene;
  static const double _regionDragThreshold = 8;
  bool _selectAreaPointerDown = false;
  int _activePointers = 0;
  final GlobalKey _viewportCanvasKey = GlobalKey();
  _PinHit? _pinPointerDownHit;
  Timer? _pinLongPressTimer;
  bool _pinLongPressArmed = false;
  bool _pinDraggingAfterLongPress = false;

  /// After long-press/drag pins, skips one [onTapUp] sheet so LP doesn't mimic a tap.
  bool _suppressPinTapSheetOnce = false;
  List<PinStatusItem> _pinStatuses = const [];
  String? _projectId;
  String? _levelId;
  bool _isSubmitting = false;
  bool _isFetchingRemoteDrawing = false;
  String? _remoteDrawingError;
  double? _activeContentAspectRatio;
  Rect? _lastObservedContentRect;
  bool _contentReprojectionQueued = false;
  Rect? _queuedContentRectFrom;
  Rect? _queuedContentRectTo;

  static const List<String> _pinStatusDialogActiveOptions = <String>[
    'Active',
    'Inactive',
  ];

  bool get _hasFile =>
      (_activeFilePath ?? '').trim().isNotEmpty &&
      File(_activeFilePath!.trim()).existsSync();

  bool get _isPdfFile {
    final path = (_activeFilePath ?? '').toLowerCase().trim();
    return path.endsWith('.pdf');
  }

  /// PDF uses pdfx matrix (single viewport); images use [InteractiveViewer].
  bool get _usePdfViewport => _isPdfFile && _pdfController != null;

  bool get _isImageFile {
    final path = (_activeFilePath ?? '').toLowerCase().trim();
    return path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp') ||
        path.endsWith('.bmp') ||
        path.endsWith('.gif');
  }

  bool get _isDrawingSelectionGesture =>
      _selectedTool == _CanvasTool.selectArea && _selectAreaPointerDown;

  bool get _isDraggingPinGesture =>
      _pinPointerDownHit != null &&
      (_pinLongPressArmed || _pinDraggingAfterLongPress);

  /// Pan only with the hand tool — never while selecting areas or placing pins.
  bool get _canPanCanvas => _selectedTool == _CanvasTool.pin;

  /// Only the hand/pan tool lets pdfx consume gestures; draw tools use the overlay.
  bool get _pdfViewerHandlesGestures =>
      _usePdfViewport && _selectedTool == _CanvasTool.pin;

  /// Block PDF pinch/pan whenever not in hand/pan mode.
  bool get _blockPdfGestures =>
      _usePdfViewport && !_pdfViewerHandlesGestures;

  /// Draw-tool overlay captures all pointers (select / line / place pin).
  bool get _overlayDrawListenerActive =>
      _selectedTool == _CanvasTool.selectArea ||
      _selectedTool == _CanvasTool.line ||
      _selectedTool == _CanvasTool.location;

  @override
  void initState() {
    super.initState();
    final projectName = (widget.projectName ?? '').trim();
    if (projectName.isNotEmpty) {
      _blockController.text = projectName;
    }
    final level = (widget.levelName ?? '').trim();
    if (level.isNotEmpty) {
      _levelController.text = level;
    }
    final incoming = widget.filePath?.trim();
    if (incoming != null &&
        incoming.isNotEmpty &&
        File(incoming).existsSync()) {
      final k = _pdfStorageKey(incoming);
      _activeFilePath = k;
      _uploadedPdfPaths.add(k);
      _initPdfControllerForActivePath();
      unawaited(_refreshActiveContentAspectRatio());
    } else {
      _activeFilePath = null;
    }
    _projectId = (widget.projectId ?? '').trim();
    _levelId = (widget.levelId ?? '').trim();
    _loadPinStatuses();
    _loadGroupAndCompositeOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeDrawingAndMarkup());
    });
  }

  Future<void> _initializeDrawingAndMarkup() async {
    await _ensureDrawingSourceReady();
    if (!mounted) return;
    await _refreshActiveContentAspectRatio();
    if (!mounted) return;
    if (_isPdfFile) {
      final path = (_activeFilePath ?? '').trim();
      if (_pdfMetadataCache == null && path.isNotEmpty) {
        await _loadPdfMetadata(path);
      }
    }
    if (!mounted) return;
    await _loadSavedLevelMarkup();
    if (!mounted) return;
    if (_isPdfFile && _pdfController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _initPdfControllerForActivePath() {
    final path = (_activeFilePath ?? '').trim();
    if (path.isEmpty || !File(path).existsSync()) return;
    if (!path.toLowerCase().endsWith('.pdf')) return;
    _detachPdfController();
    final controller = PdfControllerPinch(document: PdfDocument.openFile(path));
    controller.addListener(_onPdfLayoutChanged);
    _pdfController = controller;
    unawaited(_loadPdfMetadata(path));
  }

  Future<void> _loadPdfMetadata(String path) async {
    try {
      final cache = await PdfPageMetadataCache.fromFile(path);
      if (!mounted) return;
      setState(() => _pdfMetadataCache = cache);
    } catch (_) {
      // Pins still work via layout rects; metadata enriches PDF-point storage.
    }
  }

  void _detachPdfController() {
    _pdfController?.removeListener(_onPdfLayoutChanged);
    _pdfController?.dispose();
    _pdfController = null;
    _pdfMetadataCache = null;
  }

  bool _pdfLayoutSyncScheduled = false;

  void _onPdfLayoutChanged() {
    if (!mounted || !_isPdfFile || _pdfLayoutSyncScheduled) return;
    _pdfLayoutSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pdfLayoutSyncScheduled = false;
      if (mounted) {
        // Re-project plot polygons onto the PDF after zoom/pan/layout.
        setState(() {});
      }
    });
  }

  /// Pin anchor in canvas space (viewport-local for PDF, scene for images).
  Offset _pinAnchorScene(_CanvasPin pin) {
    final engine = _pdfEngine;
    final point = pin.pdfPoint;
    if (engine != null && point != null) {
      return engine.annotationToViewport(point) ?? pin.offset;
    }
    return pin.offset;
  }

  Future<void> _ensureDrawingSourceReady() async {
    if (!mounted) return;
    if (_hasFile) return;
    final remote = (widget.remoteDrawingUrl ?? '').trim();
    if (remote.isEmpty) return;
    setState(() {
      _isFetchingRemoteDrawing = true;
      _remoteDrawingError = null;
    });
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final path = await api.downloadDrawingForLocalEdit(remote);
      if (!mounted) return;
      _detachPdfController();
      final k = _pdfStorageKey(path);
      setState(() {
        _activeFilePath = k;
        if (!_uploadedPdfPaths.any((p) => _pdfStorageKey(p) == k)) {
          _uploadedPdfPaths.add(k);
        }
        _isFetchingRemoteDrawing = false;
        _remoteDrawingError = null;
      });
      _initPdfControllerForActivePath();
      unawaited(_refreshActiveContentAspectRatio());
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingRemoteDrawing = false;
        _remoteDrawingError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not download drawing for editing',
        );
      });
    }
  }

  @override
  void dispose() {
    _cancelPinLongPressTimer();
    _persistActiveRegionsToCache();
    _blockController.dispose();
    _levelController.dispose();
    _groupController.dispose();
    _productController.dispose();
    _detachPdfController();
    _viewerTransform.dispose();
    super.dispose();
  }

  String _pdfStorageKey(String path) => path.trim();

  void _persistActiveRegionsToCache() {
    final path = (_activeFilePath ?? '').trim();
    if (path.isEmpty) return;
    _regionsByPdfPath[path] = _snapshotRegions(_regions);
    _linesByPdfPath[path] = List<_CanvasLine>.from(_canvasLines);
  }

  /// Clears plots, pins, lines, and drafts from the canvas and per-PDF cache.
  void _clearAllCanvasMarkup() {
    _cancelPinLongPressTimer();
    setState(() {
      _selectedTool = null;
      _isSelectAllEnabled = false;
      _regions.clear();
      _canvasLines.clear();
      _activeRegionIndex = null;
      _draftStart = null;
      _draftCurrent = null;
      _lineDraftPoints.clear();
      _lineDraftCurrent = null;
      _movingRegionIndex = null;
      _regionMoveAnchorScene = null;
      _regionPressIndex = null;
      _regionPressScene = null;
      _selectAreaPointerDown = false;
      _pinPointerDownHit = null;
      _pinLongPressArmed = false;
      _pinDraggingAfterLongPress = false;
    });
    for (final path in _uploadedPdfPaths) {
      final k = _pdfStorageKey(path);
      _regionsByPdfPath[k] = const <_PlotRegion>[];
      _linesByPdfPath[k] = const <_CanvasLine>[];
    }
    final active = (_activeFilePath ?? '').trim();
    if (active.isNotEmpty) {
      _regionsByPdfPath[active] = const <_PlotRegion>[];
      _linesByPdfPath[active] = const <_CanvasLine>[];
    }
  }

  bool get _hasAnyCanvasMarkup =>
      _regions.isNotEmpty ||
      _canvasLines.isNotEmpty ||
      _lineDraftPoints.isNotEmpty ||
      _lineDraftCurrent != null ||
      _draftStart != null ||
      _draftCurrent != null;

  List<_PlotRegion> _snapshotRegions(List<_PlotRegion> regions) {
    return regions
        .map(
          (r) => r.copyWith(
            pins: List<_CanvasPin>.from(r.pins),
            lines: List<_CanvasLine>.from(r.safeLines),
          ),
        )
        .toList();
  }

  void _cancelPinLongPressTimer() {
    _pinLongPressTimer?.cancel();
    _pinLongPressTimer = null;
  }

  /// After [showDialog] returns the route subtree may rebuild for IME/viewport.
  /// Disposing controllers in that window triggers "used after being disposed".
  void _scheduleDisposeTextControllersAfterRoute(
    Iterable<TextEditingController> controllers,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in controllers) {
          c.dispose();
        }
      });
    });
  }

  void _schedulePinLongPressArm(_PinHit hit) {
    _cancelPinLongPressTimer();
    final regionIndex = hit.regionIndex;
    final pinIndex = hit.pinIndex;
    _pinLongPressTimer = Timer(const Duration(milliseconds: 460), () {
      _pinLongPressTimer = null;
      if (!mounted || _activePointers != 1) return;
      final h = _pinPointerDownHit;
      if (h == null || h.regionIndex != regionIndex || h.pinIndex != pinIndex) {
        return;
      }
      setState(() {
        _pinLongPressArmed = true;
      });
      HapticFeedback.mediumImpact();
    });
  }

  Widget _buildDrawingPreview() {
    if (_isFetchingRemoteDrawing) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDADADD)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading drawing…',
                style: AppFonts.bodySmall(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }
    if (_remoteDrawingError != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDADADD)),
        ),
        child: Center(
          child: Text(
            _remoteDrawingError!,
            textAlign: TextAlign.center,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.bodySmall(color: AppColors.muted),
          ),
        ),
      );
    }
    if (!_hasFile) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDADADD)),
        ),
        child: const Center(
          child: Icon(Icons.image_outlined, color: AppColors.muted, size: 38),
        ),
      );
    }

    final path = _activeFilePath!.trim();
    if (_isPdfFile && _pdfController != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDADADD)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: IgnorePointer(
            ignoring: _blockPdfGestures,
            child: PdfViewPinch(
              controller: _pdfController!,
              minScale: 0.5,
              maxScale: 8,
              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              pageLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorBuilder: (_, error) => Center(
                child: Text(
                  'Could not open PDF',
                  style: AppFonts.bodyMedium(color: AppColors.muted),
                ),
              ),
            ),
            ),
          ),
        ),
      );
    }

    if (_isImageFile) {
      return SizedBox.expand(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              'Could not open image',
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDADADD)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 36,
            color: AppColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            path.split(Platform.pathSeparator).last,
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _switchActivePdf(String path) {
    final trimmed = _pdfStorageKey(path);
    if (trimmed.isEmpty || trimmed == _activeFilePath) return;
    _persistActiveRegionsToCache();
    _detachPdfController();
    final nextController = PdfControllerPinch(
      document: PdfDocument.openFile(trimmed),
    );
    nextController.addListener(_onPdfLayoutChanged);
    final restored = _regionsByPdfPath[trimmed];
    final restoredLines = _linesByPdfPath[trimmed];
    setState(() {
      _activeFilePath = trimmed;
      _pdfController = nextController;
      _regions
        ..clear()
        ..addAll(restored != null ? _snapshotRegions(restored) : []);
      _canvasLines
        ..clear()
        ..addAll(
          restoredLines != null
              ? List<_CanvasLine>.from(restoredLines)
              : <_CanvasLine>[],
        );
      _activeRegionIndex = null;
      _draftStart = null;
      _draftCurrent = null;
      _movingRegionIndex = null;
      _regionMoveAnchorScene = null;
      _selectAreaPointerDown = false;
    });
    unawaited(_refreshActiveContentAspectRatio());
    unawaited(_loadPdfMetadata(trimmed));
  }

  /// Pointer → canvas coordinates (PDF viewport-local or IV scene for images).
  Offset _globalToCanvas(Offset global) {
    final ctx = _viewportCanvasKey.currentContext;
    if (ctx == null) return Offset.zero;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return Offset.zero;
    final local = box.globalToLocal(global);
    if (_isPdfFile && _pdfController != null) return local;
    return _viewerTransform.toScene(local);
  }

  Offset _globalPositionToScene(Offset global) => _globalToCanvas(global);

  double _interactionScale() =>
      math.max(_viewerTransform.value.getMaxScaleOnAxis(), 0.001);

  double _pinHitRadiusScene() =>
      math.max((_pinSizeForScreen(context) / 2 + 14) / _interactionScale(), 8);

  Offset _pinBodyCenterFromAnchor(Offset anchor) {
    final size = _pinSizeForScreen(context);
    final pointerHeight = _pinPointerHeightForScreen(context);
    // Anchor is the triangle tip (plot coordinate); icon body sits above it.
    return Offset(anchor.dx, anchor.dy - pointerHeight - (size / 2));
  }

  Size _canvasSceneSizeForNormalization() {
    final ctx = _viewportCanvasKey.currentContext;
    final box = ctx?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.size;
    }
    final mq = MediaQuery.maybeOf(context);
    if (mq != null) return mq.size;
    return const Size(1, 1);
  }

  Rect _contentRectForSceneSize(Size scene) {
    final w = scene.width <= 0 ? 1.0 : scene.width;
    final h = scene.height <= 0 ? 1.0 : scene.height;
    final aspect = _activeContentAspectRatio;
    if (aspect == null || aspect <= 0) {
      return Rect.fromLTWH(0, 0, w, h);
    }
    final containerAspect = w / h;
    double displayW;
    double displayH;
    if (containerAspect > aspect) {
      displayH = h;
      displayW = displayH * aspect;
    } else {
      displayW = w;
      displayH = displayW / aspect;
    }
    final dx = (w - displayW) / 2;
    final dy = (h - displayH) / 2;
    return Rect.fromLTWH(dx, dy, displayW, displayH);
  }

  Rect _currentContentRectInScene() {
    return _contentRectForSceneSize(_canvasSceneSizeForNormalization());
  }

  bool _rectNearEqual(Rect a, Rect b, [double epsilon = 0.5]) {
    return (a.left - b.left).abs() <= epsilon &&
        (a.top - b.top).abs() <= epsilon &&
        (a.width - b.width).abs() <= epsilon &&
        (a.height - b.height).abs() <= epsilon;
  }

  Offset _mapPointAcrossContentRects(Offset p, Rect from, Rect to) {
    final safeFromW = from.width <= 0 ? 1.0 : from.width;
    final safeFromH = from.height <= 0 ? 1.0 : from.height;
    final nx = ((p.dx - from.left) / safeFromW).clamp(0.0, 1.0);
    final ny = ((p.dy - from.top) / safeFromH).clamp(0.0, 1.0);
    return Offset(to.left + nx * to.width, to.top + ny * to.height);
  }

  void _observeViewportGeometry(Size viewportSize) {
    if (_usePdfViewport) return;
    if (!viewportSize.width.isFinite ||
        !viewportSize.height.isFinite ||
        viewportSize.width <= 0 ||
        viewportSize.height <= 0) {
      return;
    }
    final nextRect = _contentRectForSceneSize(viewportSize);
    final prevRect = _lastObservedContentRect;
    _lastObservedContentRect = nextRect;
    if (prevRect == null || _rectNearEqual(prevRect, nextRect)) return;
    if (!_hasDrawableContentForReprojection) return;
    _queueContentReprojection(prevRect, nextRect);
  }

  bool get _hasDrawableContentForReprojection =>
      _regions.isNotEmpty ||
      _canvasLines.isNotEmpty ||
      _lineDraftPoints.isNotEmpty ||
      _lineDraftCurrent != null ||
      _draftStart != null ||
      _draftCurrent != null ||
      _regionMoveAnchorScene != null;

  void _queueContentReprojection(Rect from, Rect to) {
    _queuedContentRectFrom ??= from;
    _queuedContentRectTo = to;
    if (_contentReprojectionQueued) return;
    _contentReprojectionQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentReprojectionQueued = false;
      if (!mounted) return;
      final qFrom = _queuedContentRectFrom;
      final qTo = _queuedContentRectTo;
      _queuedContentRectFrom = null;
      _queuedContentRectTo = null;
      if (qFrom == null || qTo == null || _rectNearEqual(qFrom, qTo)) return;
      setState(() {
        _regions.setAll(
          0,
          _regions
              .map((region) {
                final mappedLines = region.safeLines
                    .map(
                      (line) => _CanvasLine(
                        start: _mapPointAcrossContentRects(
                          line.start,
                          qFrom,
                          qTo,
                        ),
                        end: _mapPointAcrossContentRects(line.end, qFrom, qTo),
                      ),
                    )
                    .toList(growable: false);
                final mappedPins = region.pins.map((pin) {
                  if (_usePdfViewport && pin.pdfPoint != null) {
                    final scene = _pinAnchorScene(pin);
                    return pin.copyWith(offset: scene);
                  }
                  return pin.copyWith(
                    offset: _mapPointAcrossContentRects(
                      pin.offset,
                      qFrom,
                      qTo,
                    ),
                  );
                }).toList(growable: false);
                final mappedRect = region.safeLines.isNotEmpty
                    ? _boundingRectFromPoints(
                        mappedLines.map((line) => line.start).toList(),
                      )
                    : Rect.fromPoints(
                        _mapPointAcrossContentRects(
                          region.rect.topLeft,
                          qFrom,
                          qTo,
                        ),
                        _mapPointAcrossContentRects(
                          region.rect.bottomRight,
                          qFrom,
                          qTo,
                        ),
                      );
                return region.copyWith(
                  rect: mappedRect,
                  lines: mappedLines,
                  pins: mappedPins,
                );
              })
              .toList(growable: false),
        );
        _canvasLines.setAll(
          0,
          _canvasLines
              .map(
                (line) => _CanvasLine(
                  start: _mapPointAcrossContentRects(line.start, qFrom, qTo),
                  end: _mapPointAcrossContentRects(line.end, qFrom, qTo),
                ),
              )
              .toList(growable: false),
        );
        for (var i = 0; i < _lineDraftPoints.length; i++) {
          _lineDraftPoints[i] = _mapPointAcrossContentRects(
            _lineDraftPoints[i],
            qFrom,
            qTo,
          );
        }
        if (_lineDraftCurrent != null) {
          _lineDraftCurrent = _mapPointAcrossContentRects(
            _lineDraftCurrent!,
            qFrom,
            qTo,
          );
        }
        if (_draftStart != null) {
          _draftStart = _mapPointAcrossContentRects(_draftStart!, qFrom, qTo);
        }
        if (_draftCurrent != null) {
          _draftCurrent = _mapPointAcrossContentRects(
            _draftCurrent!,
            qFrom,
            qTo,
          );
        }
        if (_regionMoveAnchorScene != null) {
          _regionMoveAnchorScene = _mapPointAcrossContentRects(
            _regionMoveAnchorScene!,
            qFrom,
            qTo,
          );
        }
      });
    });
  }

  Offset _normalizeScenePoint(Offset scenePoint) {
    final rect = _currentContentRectInScene();
    final safeW = rect.width <= 0 ? 1.0 : rect.width;
    final safeH = rect.height <= 0 ? 1.0 : rect.height;
    return Offset(
      ((scenePoint.dx - rect.left) / safeW).clamp(0.0, 1.0),
      ((scenePoint.dy - rect.top) / safeH).clamp(0.0, 1.0),
    );
  }

  Offset _denormalizeScenePoint(double nx, double ny) {
    final rect = _currentContentRectInScene();
    return Offset(
      rect.left + nx.clamp(0.0, 1.0) * rect.width,
      rect.top + ny.clamp(0.0, 1.0) * rect.height,
    );
  }

  /// Whether the API/website expects a rotated (landscape) coordinate frame
  /// for the currently active PDF page.
  ///
  /// The website always renders drawings in landscape orientation. When the
  /// PDF page itself is portrait-natural (`width < height`) the mobile mark-up
  /// (made on a portrait viewport) must be rotated 90° before being sent to
  /// the backend so the website draws plots/pins at the exact same physical
  /// location. PDFs that are already landscape-natural need no rotation.
  bool get _shouldApplyLandscapeRotation {
    final ratio = _activeContentAspectRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) return false;
    return ratio < 1.0;
  }

  /// Rotation direction used when bridging mobile (portrait) mark-up to the
  /// website's landscape orientation. Flip to `false` if the website rotates
  /// the page counter-clockwise instead of clockwise.
  static const bool _kRotateLandscapeClockwise = true;

  /// Converts a portrait-relative normalized point `(0..1, 0..1)` (as produced
  /// by [_normalizeScenePoint]) into the landscape-relative normalized frame
  /// the website / backend expects. No-op when the page is not portrait.
  Offset _portraitNormToLandscapeApi(Offset portraitNorm) {
    if (!_shouldApplyLandscapeRotation) return portraitNorm;
    final px = portraitNorm.dx.clamp(0.0, 1.0);
    final py = portraitNorm.dy.clamp(0.0, 1.0);
    if (_kRotateLandscapeClockwise) {
      // 90° clockwise: portrait top-left -> landscape top-right.
      return Offset(1.0 - py, px);
    }
    // 90° counter-clockwise: portrait top-left -> landscape bottom-left.
    return Offset(py, 1.0 - px);
  }

  /// Inverse of [_portraitNormToLandscapeApi]: converts a landscape-relative
  /// normalized point received from the backend into the mobile portrait
  /// frame so [_denormalizeScenePoint] can place it under the user's finger.
  Offset _landscapeApiToPortraitNorm(Offset landscapeNorm) {
    if (!_shouldApplyLandscapeRotation) return landscapeNorm;
    final lx = landscapeNorm.dx.clamp(0.0, 1.0);
    final ly = landscapeNorm.dy.clamp(0.0, 1.0);
    if (_kRotateLandscapeClockwise) {
      // Inverse of 90° CW.
      return Offset(ly, 1.0 - lx);
    }
    // Inverse of 90° CCW.
    return Offset(1.0 - ly, lx);
  }

  Future<void> _refreshActiveContentAspectRatio() async {
    final path = (_activeFilePath ?? '').trim();
    if (path.isEmpty || !File(path).existsSync()) return;
    try {
      double? ratio;
      if (_isPdfFile) {
        final doc = await PdfDocument.openFile(path);
        final page = await doc.getPage(1);
        if (page.width > 0 && page.height > 0) {
          ratio = page.width / page.height;
        }
        await page.close();
        await doc.close();
      } else if (_isImageFile) {
        final bytes = await File(path).readAsBytes();
        final completer = Completer<ui.Image>();
        ui.decodeImageFromList(bytes, completer.complete);
        final image = await completer.future;
        if (image.width > 0 && image.height > 0) {
          ratio = image.width / image.height;
        }
      }
      if (!mounted) return;
      if (ratio != null && ratio > 0) {
        setState(() => _activeContentAspectRatio = ratio);
      }
    } catch (_) {
      // Keep fallback behavior when media metadata cannot be resolved.
    }
  }

  Offset _canvasPinOffsetFromApi(double x, double y, {int page = 1}) {
    final engine = _pdfEngine;
    if (engine != null) {
      final point = engine.annotationFromApiPercent(
        xRaw: x,
        yRaw: y,
        page: page,
      );
      if (point != null) {
        return engine.annotationToViewport(point) ??
            _denormalizeScenePoint(
              point.pdfX / point.pageWidth,
              point.pdfY / point.pageHeight,
            );
      }
    }
    final legacy = PdfCoordinateCodec.pageCoordinateFromApi(
      xRaw: x,
      yRaw: y,
      page: page,
    );
    if (legacy != null) {
      return _denormalizeScenePoint(legacy.xPercent, legacy.yPercent);
    }
    if (x.abs() > 1 || y.abs() > 1) return Offset(x, y);
    return _denormalizeScenePoint(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  void _applyPinScenePosition(_PinHit hit, Offset scene) {
    if (hit.regionIndex < 0 || hit.regionIndex >= _regions.length) return;
    final region = _regions[hit.regionIndex];
    final clamped = Offset(
      scene.dx.clamp(region.rect.left, region.rect.right),
      scene.dy.clamp(region.rect.top, region.rect.bottom),
    );
    if (!_regionContainsPoint(region, clamped)) return;
    if (hit.pinIndex < 0 || hit.pinIndex >= region.pins.length) return;
    final engine = _pdfEngine;
    final pdfPoint = engine?.viewportToAnnotation(clamped);
    setState(() {
      final pins = List<_CanvasPin>.from(region.pins);
      pins[hit.pinIndex] = pins[hit.pinIndex].copyWith(
        offset: clamped,
        pdfPoint: pdfPoint ?? pins[hit.pinIndex].pdfPoint,
      );
      _regions[hit.regionIndex] = region.copyWith(pins: pins);
    });
  }

  void _onToolSelected(_CanvasTool tool) {
    setState(() {
      if (_selectedTool == tool) {
        if (tool == _CanvasTool.selectArea) {
          _isSelectAllEnabled = !_isSelectAllEnabled;
        } else {
          _selectedTool = null;
        }
      } else {
        _selectedTool = tool;
        _isSelectAllEnabled = tool == _CanvasTool.selectArea;
      }
      _lineDraftPoints.clear();
      _lineDraftCurrent = null;
      _selectAreaPointerDown = false;
      _regionPressIndex = null;
      _regionPressScene = null;
    });
  }

  void _showTopToast(String message) {
    context.showTopSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onDeleteSelection() async {
    if (!_hasAnyCanvasMarkup) {
      _showTopToast('No selection to remove');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            'Remove all selection?',
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This removes all selected areas, pins, and lines from this level. '
            'Tap Submit to save the cleared drawing to the server.',
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF14141),
                foregroundColor: AppColors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove All'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) return;
    _clearAllCanvasMarkup();
    _showTopToast('All selections removed — tap Submit to update the server');
  }

  Rect _normalizedRect(Offset a, Offset b) {
    return Rect.fromLTRB(
      a.dx < b.dx ? a.dx : b.dx,
      a.dy < b.dy ? a.dy : b.dy,
      a.dx > b.dx ? a.dx : b.dx,
      a.dy > b.dy ? a.dy : b.dy,
    );
  }

  Rect _boundingRectFromPoints(List<Offset> points) {
    var minX = points.first.dx;
    var minY = points.first.dy;
    var maxX = points.first.dx;
    var maxY = points.first.dy;
    for (final p in points.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  List<_CanvasLine> _polygonLinesFromPoints(List<Offset> points) {
    if (points.length < 3) return const <_CanvasLine>[];
    final lines = <_CanvasLine>[];
    for (var i = 0; i < points.length; i++) {
      lines.add(
        _CanvasLine(start: points[i], end: points[(i + 1) % points.length]),
      );
    }
    return lines;
  }

  Rect _regionSceneRect(_PlotRegion region) {
    final engine = _pdfEngine;
    final verts = region.pdfVertices;
    if (verts != null && verts.length >= 2 && engine != null) {
      var minX = 0.0;
      var minY = 0.0;
      var maxX = 0.0;
      var maxY = 0.0;
      var any = false;
      for (final v in verts) {
        final p = engine.pdfToScreen(v);
        if (p == null) continue;
        if (!any) {
          minX = maxX = p.dx;
          minY = maxY = p.dy;
          any = true;
        } else {
          if (p.dx < minX) minX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy > maxY) maxY = p.dy;
        }
      }
      if (any) return Rect.fromLTRB(minX, minY, maxX, maxY);
    }
    if (region.pdfAnchorA != null &&
        region.pdfAnchorB != null &&
        engine != null) {
      final a = engine.pdfToScreen(region.pdfAnchorA!);
      final b = engine.pdfToScreen(region.pdfAnchorB!);
      if (a != null && b != null) return Rect.fromPoints(a, b);
    }
    return region.rect;
  }

  List<Offset> _regionScenePolygonPoints(_PlotRegion region) {
    final engine = _pdfEngine;
    final verts = region.pdfVertices;
    if (verts != null && verts.length >= 2 && engine != null) {
      final mapped = verts
          .map(engine.pdfToScreen)
          .whereType<Offset>()
          .toList(growable: false);
      if (mapped.length == 4) {
        return _orderScreenQuadByPolarAngle(mapped);
      }
      return mapped;
    }
    final lines = region.safeLines;
    if (lines.length >= 3) {
      return lines.map((l) => l.start).toList(growable: false);
    }
    final r = _regionSceneRect(region);
    return [
      r.topLeft,
      r.topRight,
      r.bottomRight,
      r.bottomLeft,
    ];
  }

  Path _regionPath(_PlotRegion region) {
    final points = _regionScenePolygonPoints(region);
    if (points.length < 3) {
      return Path()..addRect(_regionSceneRect(region));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    return path;
  }

  /// API expects 0–100 style scalars; keep 4 decimals so plot corners do not drift
  /// from integer rounding on large pages / other devices.
  double _plotCoordinateApiPercent(double fraction) {
    final pct = (fraction * 100.0).clamp(0.0, 100.0);
    return (pct * 10000).round() / 10000;
  }

  /// Clockwise order around centroid — fixes bow-tie fill when corner order from
  /// the server does not match screen winding.
  List<Offset> _orderScreenQuadByPolarAngle(List<Offset> pts) {
    if (pts.length != 4) return pts;
    var cx = 0.0;
    var cy = 0.0;
    for (final p in pts) {
      cx += p.dx;
      cy += p.dy;
    }
    cx /= 4;
    cy /= 4;
    final sorted = List<Offset>.from(pts)
      ..sort(
        (a, b) => math
            .atan2(a.dy - cy, a.dx - cx)
            .compareTo(math.atan2(b.dy - cy, b.dx - cx)),
      );
    return sorted;
  }

  /// Recompute [rect] from live PDF→viewport mapping so [rect], hit tests, and
  /// paint stay aligned after save/load and across devices.
  _PlotRegion? _plotRegionWithSyncedRect(_PlotRegion region) {
    final engine = _pdfEngine;
    final verts = region.pdfVertices;
    if (engine == null || verts == null || verts.isEmpty) return null;
    final pts = <Offset>[];
    for (final v in verts) {
      final p = engine.pdfToScreen(v);
      if (p != null) pts.add(p);
    }
    if (pts.length < 2) return null;
    var minX = pts.first.dx;
    var minY = pts.first.dy;
    var maxX = pts.first.dx;
    var maxY = pts.first.dy;
    for (final p in pts.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return region.copyWith(rect: Rect.fromLTRB(minX, minY, maxX, maxY));
  }

  Rect _regionLabelBounds(_PlotRegion region) {
    final points = _regionScenePolygonPoints(region);
    if (points.isEmpty) return _regionSceneRect(region);
    var minX = points.first.dx;
    var minY = points.first.dy;
    var maxX = points.first.dx;
    var maxY = points.first.dy;
    for (final p in points.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _assignPdfAnchorsForRect(_PlotRegion region, Rect sceneRect) {
    final engine = _pdfEngine;
    if (engine == null || !_usePdfViewport) return;
    final tl = engine.screenToPdf(sceneRect.topLeft);
    final tr = engine.screenToPdf(sceneRect.topRight);
    final br = engine.screenToPdf(sceneRect.bottomRight);
    final bl = engine.screenToPdf(sceneRect.bottomLeft);
    if (tl == null || tr == null || br == null || bl == null) return;
    region.pdfAnchorA = tl;
    region.pdfAnchorB = br;
    // Four PDF corners = same persistence contract as pins (avoids scene-% vs PDF-% mismatch on reload).
    region.pdfVertices = <PdfAnnotationPoint>[tl, tr, br, bl];
  }

  void _assignPdfVerticesForPoints(_PlotRegion region, List<Offset> scenePoints) {
    final engine = _pdfEngine;
    if (engine == null || !_usePdfViewport) return;
    final verts = <PdfAnnotationPoint>[];
    for (final p in scenePoints) {
      final ann = engine.screenToPdf(p);
      if (ann != null) verts.add(ann);
    }
    if (verts.length >= 3) region.pdfVertices = verts;
  }

  bool _regionContainsPoint(_PlotRegion region, Offset point) {
    return _regionPath(region).contains(point);
  }

  Future<String?> _showPlotNameBottomSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => const _PlotNameBottomSheetBody(),
    );
  }

  Future<void> _finalizeAreaSelection() async {
    final start = _draftStart;
    final current = _draftCurrent;
    if (start == null || current == null) return;
    final rect = _normalizedRect(start, current);
    if (rect.width < 20 || rect.height < 20) {
      setState(() {
        _draftStart = null;
        _draftCurrent = null;
      });
      return;
    }
    final region = _PlotRegion(
      rect: rect,
      name: null,
      pins: <_CanvasPin>[],
      lines: const <_CanvasLine>[],
    );
    _assignPdfAnchorsForRect(region, rect);
    final toAdd = _plotRegionWithSyncedRect(region) ?? region;
    setState(() {
      _regions.add(toAdd);
      _activeRegionIndex = _regions.length - 1;
      _draftStart = null;
      _draftCurrent = null;
    });
    final name = await _showPlotNameBottomSheet();
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      final idx = _activeRegionIndex;
      if (idx != null && idx >= 0 && idx < _regions.length) {
        _regions[idx] = _regions[idx].copyWith(name: name.trim());
      }
    });
  }

  Future<void> _finalizeRegionNameForCurrentSelection() async {
    final name = await _showPlotNameBottomSheet();
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      final idx = _activeRegionIndex;
      if (idx != null && idx >= 0 && idx < _regions.length) {
        _regions[idx] = _regions[idx].copyWith(name: name.trim());
      }
    });
  }

  void _onCanvasTapUp(TapUpDetails details) {
    final scenePoint = _globalPositionToScene(details.globalPosition);
    if (_selectedTool == _CanvasTool.line) {
      _handleLineToolTap(scenePoint);
      return;
    }
    if (_selectedTool == _CanvasTool.pin ||
        _selectedTool == _CanvasTool.share ||
        _selectedTool == _CanvasTool.selectArea) {
      return;
    }

    final isPinTool = _selectedTool == _CanvasTool.location;
    if (!isPinTool) return;
    if (_regions.isEmpty) {
      _showTopToast('Select an area first');
      return;
    }
    final p = scenePoint;
    int? targetIndex;
    for (var i = _regions.length - 1; i >= 0; i--) {
      if (_regionContainsPoint(_regions[i], p)) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex == null) {
      _showTopToast('Pin must be inside selected area');
      return;
    }
    final selectedGroupId = _selectedGroupId;
    final selectedCompositeItemId = _selectedCompositeItemId;
    final group = _groupController.text.trim();
    final product = _productController.text.trim();
    if (selectedGroupId == null ||
        selectedCompositeItemId == null ||
        group.isEmpty ||
        product.isEmpty) {
      _showTopToast('Please select Group and Product before adding pins');
      return;
    }
    setState(() {
      _activeRegionIndex = targetIndex;
      final region = _regions[targetIndex!];
      final engine = _pdfEngine;
      final pdfPoint = engine?.viewportToAnnotation(p);
      final anchor = pdfPoint != null
          ? (engine!.annotationToViewport(pdfPoint) ?? p)
          : p;
      final nextPins = List<_CanvasPin>.from(region.pins)
        ..add(
          _CanvasPin(
            offset: anchor,
            pdfPoint: pdfPoint,
            productName: product,
            status: 'In Progress',
            statusId: _statusIdByName('In Progress'),
            groupId: selectedGroupId,
            compositeItemId: selectedCompositeItemId,
            quantity: 1,
            blockName: _blockController.text.trim(),
            levelName: _levelController.text.trim(),
            zoneName: (region.name ?? '').trim(),
            variation: _variationOn ? 'Yes' : 'No',
            droppedAt: DateTime.now(),
            description: '',
          ),
        );
      _regions[targetIndex] = region.copyWith(pins: nextPins);
    });
  }

  /// Highest-index region at [scenePoint] (painted on top when plots overlap).
  int? _topRegionIndexContaining(Offset scenePoint) {
    for (var i = _regions.length - 1; i >= 0; i--) {
      if (_regionContainsPoint(_regions[i], scenePoint)) return i;
    }
    return null;
  }

  _PinHit? _findPinAtScenePoint(Offset scenePoint) {
    final hitRadius = _pinHitRadiusScene();
    _PinHit? bestHit;
    var bestD = double.infinity;
    for (var r = 0; r < _regions.length; r++) {
      final pins = _regions[r].pins;
      for (var p = 0; p < pins.length; p++) {
        final pinAnchor = _pinAnchorScene(pins[p]);
        final bodyCenter = _pinBodyCenterFromAnchor(pinAnchor);
        final d = math.min(
          (pinAnchor - scenePoint).distance,
          (bodyCenter - scenePoint).distance,
        );
        if (d < bestD && d <= hitRadius) {
          bestD = d;
          bestHit = _PinHit(regionIndex: r, pinIndex: p);
        }
      }
    }
    return bestHit;
  }

  Future<void> _openPinDetailSheet({
    required int regionIndex,
    required int pinIndex,
  }) async {
    if (regionIndex < 0 || regionIndex >= _regions.length) return;
    final pins = _regions[regionIndex].pins;
    if (pinIndex < 0 || pinIndex >= pins.length) return;
    final currentPin = pins[pinIndex];

    final result = await showModalBottomSheet<_PinSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _PinDetailBottomSheet(
        pinNumber: pinIndex + 1,
        pin: currentPin,
        pinStatuses: _pinStatuses,
        onCreatePinStatus: _createPinStatus,
        onEditPinStatus: _editPinStatus,
      ),
    );
    if (!mounted || result == null) return;
    if (result.removePin) {
      setState(() {
        final nextPins = List<_CanvasPin>.from(_regions[regionIndex].pins)
          ..removeAt(pinIndex);
        _regions[regionIndex] = _regions[regionIndex].copyWith(pins: nextPins);
      });
      return;
    }
    final updated = result.updatedPin;
    if (updated == null) return;
    setState(() {
      final nextPins = List<_CanvasPin>.from(_regions[regionIndex].pins);
      nextPins[pinIndex] = updated;
      _regions[regionIndex] = _regions[regionIndex].copyWith(pins: nextPins);
    });
  }

  Future<void> _loadPinStatuses() async {
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final statuses = await api.fetchPinStatuses();
      if (!mounted) return;
      setState(() => _pinStatuses = statuses);
    } catch (_) {
      // Keep local fallback statuses if API not available.
    }
  }

  Future<void> _loadGroupAndCompositeOptions() async {
    setState(() => _isLoadingGroups = true);
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final groups = await api.fetchGroups();
      if (!mounted) return;
      setState(() {
        _groupOptions = groups;
        _isLoadingGroups = false;
        final selectedStillValid = _groupOptions.any(
          (g) => g.id == _selectedGroupId,
        );
        if (!selectedStillValid) {
          _selectedGroupId = null;
          _groupController.clear();
          _selectedCompositeItemId = null;
          _productController.clear();
          _productOptions = const <CompositeItemOption>[];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingGroups = false);
      _showTopToast(
        ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not load groups',
        ),
      );
    }
  }

  Future<void> _loadCompositeItemsForGroup(int? groupId) async {
    if (groupId == null) {
      setState(() {
        _productOptions = const <CompositeItemOption>[];
        _selectedCompositeItemId = null;
        _productController.clear();
      });
      return;
    }
    setState(() => _isLoadingCompositeItems = true);
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final products = await api.fetchCompositeItems(groupId: groupId);
      if (!mounted) return;
      setState(() {
        _productOptions = products;
        _isLoadingCompositeItems = false;
        final selectedStillValid = products.any(
          (item) => item.id == _selectedCompositeItemId,
        );
        if (!selectedStillValid) {
          _selectedCompositeItemId = null;
          _productController.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCompositeItems = false;
        _productOptions = const <CompositeItemOption>[];
        _selectedCompositeItemId = null;
        _productController.clear();
      });
      _showTopToast(
        ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not load composite items',
        ),
      );
    }
  }

  Future<PinStatusItem?> _createPinStatus() async {
    final statusController = TextEditingController();
    final bgController = TextEditingController(text: '#E5E7EB');
    final textController = TextEditingController(text: '#374151');
    String activeValue = _pinStatusDialogActiveOptions.first;
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Pin Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: statusController,
                hintText: 'Status name',
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: bgController,
                hintText: 'Background color (#E5E7EB)',
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: textController,
                hintText: 'Text color (#374151)',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: activeValue,
                items: _pinStatusDialogActiveOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => activeValue = value);
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFF3F3F4),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFE3E3E5)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(<String, String>{
                'status_name': statusController.text.trim(),
                'bg_colour': bgController.text.trim(),
                'text_colour': textController.text.trim(),
                'is_active': activeValue == 'Active' ? 'true' : 'false',
              }),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    _scheduleDisposeTextControllersAfterRoute(<TextEditingController>[
      statusController,
      bgController,
      textController,
    ]);
    if (!mounted || payload == null) return null;
    final statusName = (payload['status_name'] ?? '').trim();
    final bg = (payload['bg_colour'] ?? '').trim();
    final text = (payload['text_colour'] ?? '').trim();
    final isActiveCreate =
        (payload['is_active'] ?? 'true').toLowerCase() != 'false';
    if (statusName.isEmpty || bg.isEmpty || text.isEmpty) return null;
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final created = await api.createPinStatus(
        statusName: statusName,
        bgColour: bg,
        textColour: text,
        isActive: isActiveCreate,
      );
      if (!mounted) return null;
      await _loadPinStatuses();
      return created;
    } catch (e) {
      if (!mounted) return null;
      _showTopToast(
        ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not create pin status',
        ),
      );
      return null;
    }
  }

  Future<PinStatusItem?> _editPinStatus(PinStatusItem source) async {
    final statusController = TextEditingController(text: source.statusName);
    final bgController = TextEditingController(text: source.bgColour);
    final textController = TextEditingController(text: source.textColour);
    String activeValue = source.isActive ? 'Active' : 'Inactive';
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Pin Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: statusController,
                hintText: 'Status name',
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: bgController,
                hintText: 'Background color (#E5E7EB)',
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: textController,
                hintText: 'Text color (#374151)',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: activeValue,
                items: _pinStatusDialogActiveOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => activeValue = value);
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFF3F3F4),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFE3E3E5)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(<String, String>{
                'status_name': statusController.text.trim(),
                'bg_colour': bgController.text.trim(),
                'text_colour': textController.text.trim(),
                'is_active': activeValue == 'Active' ? 'true' : 'false',
              }),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    _scheduleDisposeTextControllersAfterRoute(<TextEditingController>[
      statusController,
      bgController,
      textController,
    ]);
    if (!mounted || payload == null) return null;
    final statusName = (payload['status_name'] ?? '').trim();
    final bg = (payload['bg_colour'] ?? '').trim();
    final text = (payload['text_colour'] ?? '').trim();
    final isActive = (payload['is_active'] ?? 'true').toLowerCase() == 'true';
    if (statusName.isEmpty || bg.isEmpty || text.isEmpty) return null;
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final updated = await api.updatePinStatus(
        statusId: source.id,
        statusName: statusName,
        bgColour: bg,
        textColour: text,
        isActive: isActive,
      );
      if (!mounted) return null;
      await _loadPinStatuses();
      return updated;
    } catch (e) {
      if (!mounted) return null;
      _showTopToast(
        ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not update pin status',
        ),
      );
      return null;
    }
  }

  Future<void> _loadSavedLevelMarkup() async {
    final projectId = (_projectId ?? '').trim();
    final levelId = (_levelId ?? '').trim();
    if (projectId.isEmpty || levelId.isEmpty) return;
    if (_activeContentAspectRatio == null && _hasFile) {
      await _refreshActiveContentAspectRatio();
    }
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final levels = await api.fetchProjectLevels(projectId: projectId);
      final level = levels
          .where((e) => e.id.trim() == levelId)
          .cast<ProjectLevelItem?>()
          .firstWhere((e) => e != null, orElse: () => null);
      if (!mounted || level == null) return;
      final loaded = <_PlotRegion>[];
      for (final plot in level.plots) {
        final name = (plot['name'] ?? '').toString().trim();
        final plotPageRaw = plot['page'];
        final plotPage = plotPageRaw is int
            ? plotPageRaw
            : (plotPageRaw is num ? plotPageRaw.toInt() : 1);
        final pdfVerts = _isPdfFile
            ? _pdfVerticesFromPlotCoordinates(
                plot['coordinates'],
                page: plotPage,
              )
            : null;
        final coordinatePoints = pdfVerts != null
            ? _viewportPointsFromPdfVertices(pdfVerts)
            : _pointsFromCoordinates(plot['coordinates']);
        if (pdfVerts == null && coordinatePoints.length < 2) continue;
        final rect = coordinatePoints.length >= 2
            ? _rectFromCoordinatePoints(coordinatePoints)
            : (pdfVerts != null ? Rect.zero : null);
        if (rect == null && pdfVerts == null) continue;
        final shapeLines = coordinatePoints.length >= 3
            ? _linesFromCoordinatePoints(coordinatePoints)
            : const <_CanvasLine>[];
        final plotIdRaw = plot['id'];
        final serverPlotId = plotIdRaw is int
            ? plotIdRaw
            : int.tryParse('${plotIdRaw ?? ''}');
        final pins = <_CanvasPin>[];
        final rawPins = plot['pins'];
        if (rawPins is List) {
          for (final pinRaw in rawPins) {
            if (pinRaw is! Map) continue;
            final p = Map<String, dynamic>.from(pinRaw);
            final x = _toDouble(p['x_coordinate']);
            final y = _toDouble(p['y_coordinate']);
            if (x == null || y == null) continue;
            final statusId = p['status'] is int
                ? p['status'] as int
                : int.tryParse('${p['status'] ?? ''}');
            final pinIdRaw = p['id'];
            final serverPinId = pinIdRaw is int
                ? pinIdRaw
                : int.tryParse('${pinIdRaw ?? ''}');
            final pageRaw = plot['page'];
            final page = pageRaw is int
                ? pageRaw
                : (pageRaw is num ? pageRaw.toInt() : 1);
            final engine = _pdfEngine;
            final pdfPoint = engine?.annotationFromApiPercent(
                  xRaw: x,
                  yRaw: y,
                  page: page,
                ) ??
                PdfCoordinateCodec.annotationFromApi(
                  xRaw: x,
                  yRaw: y,
                  page: page,
                  cache: _pdfMetadataCache,
                );
            pins.add(
              _CanvasPin(
                offset: _canvasPinOffsetFromApi(x, y, page: page),
                pdfPoint: pdfPoint,
                productName: '',
                status: _statusNameById(statusId),
                statusId: statusId,
                groupId: p['group'] is int
                    ? p['group'] as int
                    : int.tryParse('${p['group'] ?? ''}'),
                compositeItemId: p['composite_item'] is int
                    ? p['composite_item'] as int
                    : int.tryParse('${p['composite_item'] ?? ''}'),
                quantity:
                    (p['quantity'] is int
                        ? p['quantity'] as int
                        : int.tryParse('${p['quantity'] ?? ''}')) ??
                    1,
                blockName: _blockController.text.trim(),
                levelName: _levelController.text.trim(),
                zoneName: name,
                variation: (p['variation'] == true) ? 'Yes' : 'No',
                droppedAt: DateTime.now(),
                description: '',
                serverPinId: serverPinId,
              ),
            );
          }
        }
        final region = _PlotRegion(
          rect: rect ?? Rect.zero,
          name: name,
          pins: pins,
          lines: shapeLines,
          serverPlotId: serverPlotId,
        );
        if (pdfVerts != null) {
          _attachPdfPlotGeometry(region, pdfVerts);
        }
        loaded.add(_plotRegionWithSyncedRect(region) ?? region);
      }
      if (!mounted) return;
      setState(() {
        _regions
          ..clear()
          ..addAll(loaded);
        _canvasLines.clear();
        final k = (_activeFilePath ?? '').trim();
        if (k.isNotEmpty) {
          _regionsByPdfPath[k] = _snapshotRegions(_regions);
          _linesByPdfPath[k] = List<_CanvasLine>.from(_canvasLines);
        }
      });
      if (mounted) setState(() {});
    } catch (_) {
      // keep UI editable even if preload fails
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  /// Plot polygon vertices in PDF user space (same contract as pins).
  List<PdfAnnotationPoint>? _pdfVerticesFromPlotCoordinates(
    dynamic rawCoordinates, {
    int page = 1,
  }) {
    if (rawCoordinates is! List || rawCoordinates.isEmpty) return null;
    final engine = _pdfEngine;
    final verts = <PdfAnnotationPoint>[];
    for (final point in rawCoordinates) {
      double? x;
      double? y;
      if (point is List && point.length >= 2) {
        x = _toDouble(point[0]);
        y = _toDouble(point[1]);
      } else if (point is Map) {
        final map = Map<String, dynamic>.from(point);
        x = _toDouble(map['x'] ?? map['x_coordinate'] ?? map['left']);
        y = _toDouble(map['y'] ?? map['y_coordinate'] ?? map['top']);
      }
      if (x == null || y == null) continue;
      final ann =
          engine?.annotationFromApiPercent(xRaw: x, yRaw: y, page: page) ??
          PdfCoordinateCodec.annotationFromApi(
            xRaw: x,
            yRaw: y,
            page: page,
            cache: _pdfMetadataCache,
          );
      if (ann != null) verts.add(ann);
    }
    return verts.length >= 2 ? verts : null;
  }

  List<Offset> _viewportPointsFromPdfVertices(List<PdfAnnotationPoint> verts) {
    final engine = _pdfEngine;
    if (engine == null) return const <Offset>[];
    return verts.map(engine.pdfToScreen).whereType<Offset>().toList(growable: false);
  }

  void _attachPdfPlotGeometry(_PlotRegion region, List<PdfAnnotationPoint> verts) {
    region.pdfVertices = verts;
    if (verts.length >= 2) {
      region.pdfAnchorA = verts.first;
      region.pdfAnchorB = verts.last;
    }
  }

  List<List<double>> _plotCoordinatesPayloadForApi(_PlotRegion region) {
    final verts = region.pdfVertices;
    if (verts != null && verts.isNotEmpty) {
      return verts.map((p) {
        final w = p.pageWidth > 0 ? p.pageWidth : 1.0;
        final h = p.pageHeight > 0 ? p.pageHeight : 1.0;
        return <double>[
          _plotCoordinateApiPercent(p.pdfX / w),
          _plotCoordinateApiPercent(p.pdfY / h),
        ];
      }).toList(growable: false);
    }
    final coordinatePoints = region.safeLines.isNotEmpty
        ? region.safeLines.map((line) => line.start).toList(growable: false)
        : <Offset>[
            region.rect.topLeft,
            region.rect.topRight,
            region.rect.bottomRight,
            region.rect.bottomLeft,
          ];
    return coordinatePoints
        .map((p) {
          final portraitNorm = _normalizeScenePoint(p);
          final landscapeNorm = _portraitNormToLandscapeApi(portraitNorm);
          return <double>[landscapeNorm.dx, landscapeNorm.dy];
        })
        .toList(growable: false);
  }

  List<Offset> _pointsFromCoordinates(dynamic rawCoordinates) {
    if (rawCoordinates is! List || rawCoordinates.isEmpty) {
      return const <Offset>[];
    }
    if (_usePdfViewport) {
      final verts = _pdfVerticesFromPlotCoordinates(rawCoordinates);
      if (verts != null) {
        final viewportPts = _viewportPointsFromPdfVertices(verts);
        if (viewportPts.isNotEmpty) return viewportPts;
      }
    }
    final points = <Offset>[];
    for (final point in rawCoordinates) {
      double? x;
      double? y;
      if (point is List && point.length >= 2) {
        x = _toDouble(point[0]);
        y = _toDouble(point[1]);
      } else if (point is Map) {
        final map = Map<String, dynamic>.from(point);
        x = _toDouble(map['x'] ?? map['x_coordinate'] ?? map['left']);
        y = _toDouble(map['y'] ?? map['y_coordinate'] ?? map['top']);
      }
      if (x == null || y == null) continue;
      if (x >= 0 && x <= 1 && y >= 0 && y <= 1) {
        final portraitNorm = _landscapeApiToPortraitNorm(Offset(x, y));
        points.add(_denormalizeScenePoint(portraitNorm.dx, portraitNorm.dy));
      } else {
        points.add(Offset(x, y));
      }
    }
    return points;
  }

  Rect? _rectFromCoordinatePoints(List<Offset> points) {
    if (points.length < 2) return null;
    var minX = points.first.dx;
    var minY = points.first.dy;
    var maxX = points.first.dx;
    var maxY = points.first.dy;
    for (final p in points.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  List<_CanvasLine> _linesFromCoordinatePoints(List<Offset> points) {
    if (points.length < 3) return const <_CanvasLine>[];
    final normalized = List<Offset>.from(points);
    if (normalized.length > 2 &&
        (normalized.first - normalized.last).distance < 0.5) {
      normalized.removeLast();
    }
    if (normalized.length < 3) return const <_CanvasLine>[];
    final lines = <_CanvasLine>[];
    for (var i = 0; i < normalized.length; i++) {
      lines.add(
        _CanvasLine(
          start: normalized[i],
          end: normalized[(i + 1) % normalized.length],
        ),
      );
    }
    return lines;
  }

  String _statusNameById(int? statusId) {
    if (statusId == null) return 'In Progress';
    for (final s in _pinStatuses) {
      final parsed = int.tryParse(s.id);
      if (parsed == statusId) return s.statusName;
    }
    return 'In Progress';
  }

  int _statusIdByName(String statusName) {
    final normalized = statusName.trim().toLowerCase();
    for (final s in _pinStatuses) {
      if (s.statusName.trim().toLowerCase() == normalized) {
        return int.tryParse(s.id) ?? 1;
      }
    }
    return 1;
  }

  Future<void> _submitLevelPlots() async {
    if (_isSubmitting) return;
    final projectId = (_projectId ?? '').trim();
    final levelId = (_levelId ?? '').trim();
    if (projectId.isEmpty || levelId.isEmpty) {
      _showTopToast('Missing project or level id for submit');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final plotsPayload = <Map<String, dynamic>>[];
      for (var i = 0; i < _regions.length; i++) {
        final region = _regions[i];
        final pins = <Map<String, dynamic>>[];
        for (var p = 0; p < region.pins.length; p++) {
          final pin = region.pins[p];
          final engine = _pdfEngine;
          final pdfPoint =
              pin.pdfPoint ??
              (engine != null
                  ? engine.viewportToAnnotation(pin.offset)
                  : null);
          final apiCoords = pdfPoint != null
              ? PdfCoordinateCodec.annotationToApi(pdfPoint)
              : <String, dynamic>{
                  'x_coordinate':
                      (_normalizeScenePoint(pin.offset).dx * 100).round(),
                  'y_coordinate':
                      (_normalizeScenePoint(pin.offset).dy * 100).round(),
                };
          pins.add(<String, dynamic>{
            if (pin.serverPinId != null) 'id': pin.serverPinId,
            if (pdfPoint != null) 'page': pdfPoint.page,
            ...apiCoords,
            'status': pin.statusId ?? _statusIdByName(pin.status),
            'group': pin.groupId,
            'item': pin.compositeItemId,
            'quantity': pin.quantity < 1 ? 1 : pin.quantity,
            if (pin.variation.trim().isNotEmpty)
              'variation': pin.variation.toLowerCase() == 'yes',
          });
        }
        final normalizedCoordinates = _plotCoordinatesPayloadForApi(region);
        plotsPayload.add(<String, dynamic>{
          if (region.serverPlotId != null) 'id': region.serverPlotId,
          'name': (region.name ?? '').trim().isEmpty
              ? 'Plot ${i + 1}'
              : region.name!.trim(),
          'page': 1,
          'coordinates': normalizedCoordinates,
          'pins': pins,
        });
      }
      final payload = <String, dynamic>{'plots': plotsPayload};
      debugPrint(
        '[DrawingCanvas] updateLevelPlots payload:\n'
        '${const JsonEncoder.withIndent('  ').convert(payload)}',
      );
      final api = ref.read(quoteProjectApiClientProvider);
      await api.updateLevelPlots(
        projectId: projectId,
        levelId: levelId,
        plots: plotsPayload,
      );
      if (!mounted) return;
      final clearedAll = plotsPayload.isEmpty;
      if (context.canPop()) {
        context.pop(true);
      } else {
        if (clearedAll) {
          _clearAllCanvasMarkup();
        } else {
          await _loadSavedLevelMarkup();
        }
        if (!mounted) return;
        _showTopToast(
          clearedAll
              ? 'All plots and pins removed from the server'
              : 'Selection and pins saved successfully',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showTopToast(
        ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not save plot/pin data',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildCanvasStack() {
    final pinLayerInteractive =
        !_overlayDrawListenerActive && _selectedTool == _CanvasTool.share;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _buildDrawingPreview()),
        Positioned.fill(child: _buildRegionPaintLayer()),
        // Always paint API and user pins; draw overlay sits on top when active.
        Positioned.fill(
          child: _buildPinHitTargetsLayer(interactive: pinLayerInteractive),
        ),
        if (_selectedTool == _CanvasTool.selectArea &&
            _uploadedPdfPaths.length > 1)
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE3E3E5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    'Each uploaded PDF keeps its own areas and pins — use the '
                    'tabs above the canvas to switch.',
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
                ),
              ),
            ),
          ),
        if (_overlayDrawListenerActive)
          Positioned.fill(child: _buildDrawGestureOverlay()),
      ],
    );
  }

  /// Pins stay visible on every tool; share tool enables tap-to-open sheet.
  Widget _buildPinHitTargetsLayer({required bool interactive}) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        for (var r = 0; r < _regions.length; r++)
          for (var i = 0; i < _regions[r].pins.length; i++)
            Builder(
              builder: (context) {
                final pin = _regions[r].pins[i];
                final anchor = _pinAnchorScene(pin);
                final pinSize = _pinSizeForScreen(context);
                final pointerH = _pinPointerHeightForScreen(context);
                final pinWidget = PinView(
                  number: i + 1,
                  size: pinSize,
                  pointerHeight: pointerH,
                );
                return Positioned(
                  left: anchor.dx - pinSize / 2,
                  top: anchor.dy - pinSize - pointerH,
                  child: interactive
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openPinDetailSheet(
                            regionIndex: r,
                            pinIndex: i,
                          ),
                          child: pinWidget,
                        )
                      : IgnorePointer(child: pinWidget),
                );
              },
            ),
      ],
    );
  }

  Widget _buildRegionPaintLayer() {
    final draftRect = (_draftStart != null && _draftCurrent != null)
        ? _normalizedRect(_draftStart!, _draftCurrent!)
        : null;
    final draftLinePoints = _lineDraftPoints;
    final draftLineCurrent = _lineDraftCurrent;
    return Stack(
      children: [
        for (var r = 0; r < _regions.length; r++)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RegionShapePainter(
                  path: _regionPath(_regions[r]),
                  fillColor: _regionFillColor(r),
                  borderColor: _regionBorderColor(r),
                  borderWidth:
                      r == _activeRegionIndex &&
                          _selectedTool == _CanvasTool.selectArea
                      ? 2.0
                      : _regionBorderWidth,
                  dashPattern: _regionDashPattern,
                  crossCorners: _regionScenePolygonPoints(_regions[r]),
                  crossColor: _regionBorderColor(r).withValues(alpha: 0.38),
                  crossDashPattern: _regionCrossDashPattern,
                ),
              ),
            ),
          ),
        if (draftRect != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RegionShapePainter(
                  path: Path()..addRect(draftRect),
                  fillColor: _regionFillColor(_regions.length),
                  borderColor: _regionBorderColor(_regions.length),
                  borderWidth: _regionBorderWidth,
                  dashPattern: _regionDashPattern,
                  crossCorners: [
                    draftRect.topLeft,
                    draftRect.topRight,
                    draftRect.bottomRight,
                    draftRect.bottomLeft,
                  ],
                  crossColor: _regionBorderColor(
                    _regions.length,
                  ).withValues(alpha: 0.32),
                  crossDashPattern: _regionCrossDashPattern,
                ),
              ),
            ),
          ),
        for (final line in _canvasLines)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RegionLinePainter(
                  start: line.start,
                  end: line.end,
                  color: const Color(0xFF0F172A),
                  strokeWidth: 2.2,
                ),
              ),
            ),
          ),
        for (var i = 1; i < draftLinePoints.length; i++)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RegionLinePainter(
                  start: draftLinePoints[i - 1],
                  end: draftLinePoints[i],
                  color: _regionBorderColor(_regions.length),
                  strokeWidth: 1.2,
                ),
              ),
            ),
          ),
        if (draftLinePoints.isNotEmpty && draftLineCurrent != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RegionLinePainter(
                  start: draftLinePoints.last,
                  end: draftLineCurrent,
                  color: _regionBorderColor(_regions.length),
                  strokeWidth: 1.2,
                ),
              ),
            ),
          ),
        for (final point in draftLinePoints)
          Positioned(
            left: point.dx - 4,
            top: point.dy - 4,
            child: IgnorePointer(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        for (var r = 0; r < _regions.length; r++) ...[
          if ((_regions[r].name ?? '').trim().isNotEmpty)
            Positioned.fromRect(
              rect: _regionLabelBounds(_regions[r]),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    _regions[r].name!.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppFonts.bodySmall(
                      color: _regionBorderColor(r),
                    ).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDrawGestureOverlay() {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent e) {
        _activePointers++;
        if (_activePointers > 1) {
          _selectAreaPointerDown = false;
          _cancelPinLongPressTimer();
          _pinPointerDownHit = null;
          _pinLongPressArmed = false;
          _pinDraggingAfterLongPress = false;
          _lineDraftPoints.clear();
          _lineDraftCurrent = null;
          _regionPressIndex = null;
          _regionPressScene = null;
        } else {
          _suppressPinTapSheetOnce = false;
          _pinLongPressArmed = false;
          _pinDraggingAfterLongPress = false;
          _cancelPinLongPressTimer();
          _selectAreaPointerDown = false;
          _regionPressIndex = null;
          _regionPressScene = null;
          final downScene = _globalPositionToScene(e.position);
          if (_selectedTool == _CanvasTool.location) {
            _pinPointerDownHit = _findPinAtScenePoint(downScene);
            if (_pinPointerDownHit != null) {
              _schedulePinLongPressArm(_pinPointerDownHit!);
            }
          } else {
            _pinPointerDownHit = null;
          }
          if (_pinPointerDownHit == null &&
              _selectedTool == _CanvasTool.selectArea) {
            _selectAreaPointerDown = true;
            _startSelectAreaFromScene(downScene);
          }
        }
      },
      onPointerMove: (PointerMoveEvent e) {
        if (_activePointers != 1) return;
        final scene = _globalPositionToScene(e.position);
        final hit = _pinPointerDownHit;
        if (hit != null && _pinLongPressArmed) {
          _applyPinScenePosition(hit, scene);
          _pinDraggingAfterLongPress = true;
          return;
        }
        if (_selectAreaPointerDown) {
          _updateSelectAreaFromScene(scene);
          return;
        }
        if (_selectedTool == _CanvasTool.line &&
            _lineDraftPoints.isNotEmpty) {
          setState(() => _lineDraftCurrent = scene);
        }
      },
      onPointerUp: (PointerUpEvent e) {
        _cancelPinLongPressTimer();
        final hadPinSession = _pinPointerDownHit != null;
        final skipTapSheet =
            hadPinSession &&
            (_pinLongPressArmed || _pinDraggingAfterLongPress);
        if (hadPinSession && skipTapSheet) {
          _suppressPinTapSheetOnce = true;
        }
        _pinPointerDownHit = null;
        _pinLongPressArmed = false;
        _pinDraggingAfterLongPress = false;
        if (_selectAreaPointerDown) {
          _selectAreaPointerDown = false;
          _endSelectAreaGesture();
        }
        if (_activePointers > 0) _activePointers--;
      },
      onPointerCancel: (_) {
        _cancelPinLongPressTimer();
        _pinPointerDownHit = null;
        _pinLongPressArmed = false;
        _pinDraggingAfterLongPress = false;
        _lineDraftPoints.clear();
        _lineDraftCurrent = null;
        _regionPressIndex = null;
        _regionPressScene = null;
        if (_selectAreaPointerDown) {
          _selectAreaPointerDown = false;
          if (_movingRegionIndex != null) {
            setState(() {
              _movingRegionIndex = null;
              _regionMoveAnchorScene = null;
            });
          } else {
            setState(() {
              _draftStart = null;
              _draftCurrent = null;
            });
          }
        }
        if (_activePointers > 0) _activePointers--;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: _onCanvasTapUp,
        child: const SizedBox.expand(),
      ),
    );
  }

  void _startSelectAreaFromScene(Offset p) {
    if (_selectedTool != _CanvasTool.selectArea) return;
    final hitRegion = _topRegionIndexContaining(p);
    if (hitRegion != null) {
      setState(() {
        _regionPressIndex = hitRegion;
        _regionPressScene = p;
        _activeRegionIndex = hitRegion;
        _movingRegionIndex = null;
        _regionMoveAnchorScene = null;
        _draftStart = null;
        _draftCurrent = null;
      });
      return;
    }
    setState(() {
      _regionPressIndex = null;
      _regionPressScene = null;
      _movingRegionIndex = null;
      _regionMoveAnchorScene = null;
      _activeRegionIndex = null;
      _draftStart = p;
      _draftCurrent = p;
    });
  }

  void _updateSelectAreaFromScene(Offset p) {
    if (_selectedTool != _CanvasTool.selectArea || !_selectAreaPointerDown) {
      return;
    }
    final pressIdx = _regionPressIndex;
    final pressScene = _regionPressScene;
    if (pressIdx != null &&
        pressScene != null &&
        _movingRegionIndex == null &&
        (p - pressScene).distance >= _regionDragThreshold) {
      setState(() {
        _movingRegionIndex = pressIdx;
        _regionMoveAnchorScene = pressScene;
      });
    }
    final moveIdx = _movingRegionIndex;
    final anchor = _regionMoveAnchorScene;
    if (moveIdx != null &&
        anchor != null &&
        moveIdx >= 0 &&
        moveIdx < _regions.length) {
      final newAnchor = p;
      final delta = newAnchor - anchor;
      if (delta == Offset.zero) return;
      setState(() {
        final region = _regions[moveIdx];
        final nextRect = region.rect.shift(delta);
        final nextPins = region.pins.map((pin) {
          final anchor = _pinAnchorScene(pin);
          final newAnchor = anchor + delta;
          final engine = _pdfEngine;
          final newPoint = engine?.viewportToAnnotation(newAnchor);
          return pin.copyWith(
            offset: newAnchor,
            pdfPoint: newPoint ?? pin.pdfPoint,
          );
        }).toList();
        final nextLines = region.safeLines
            .map(
              (line) =>
                  _CanvasLine(start: line.start + delta, end: line.end + delta),
            )
            .toList();
        final updated = region.copyWith(
          rect: nextRect,
          pins: nextPins,
          lines: nextLines,
        );
        _assignPdfAnchorsForRect(updated, nextRect);
        if (nextLines.length >= 3) {
          _assignPdfVerticesForPoints(
            updated,
            nextLines.map((l) => l.start).toList(),
          );
        }
        _regions[moveIdx] = _plotRegionWithSyncedRect(updated) ?? updated;
        _regionMoveAnchorScene = newAnchor;
      });
      return;
    }
    if (_draftStart == null) return;
    setState(() => _draftCurrent = p);
  }

  void _endSelectAreaGesture() {
    if (_movingRegionIndex != null) {
      setState(() {
        _movingRegionIndex = null;
        _regionMoveAnchorScene = null;
        _regionPressIndex = null;
        _regionPressScene = null;
      });
      return;
    }
    if (_regionPressIndex != null) {
      setState(() {
        _activeRegionIndex = _regionPressIndex;
        _regionPressIndex = null;
        _regionPressScene = null;
      });
      return;
    }
    unawaited(_finalizeAreaSelection());
  }

  void _handleLineToolTap(Offset scenePoint) {
    if (_selectedTool != _CanvasTool.line) return;
    final points = List<Offset>.from(_lineDraftPoints);
    if (points.isEmpty) {
      setState(() {
        _lineDraftPoints.add(scenePoint);
        _lineDraftCurrent = scenePoint;
      });
      return;
    }

    final first = points.first;
    final previous = points.last;
    final closesPolygon =
        points.length >= 3 && (scenePoint - first).distance <= 20;
    if (closesPolygon) {
      final polygonPoints = List<Offset>.from(points);
      final polygonLines = _polygonLinesFromPoints(polygonPoints);
      final rect = _boundingRectFromPoints(polygonPoints);
      final region = _PlotRegion(
        rect: rect,
        name: null,
        pins: <_CanvasPin>[],
        lines: polygonLines,
      );
      _assignPdfVerticesForPoints(region, polygonPoints);
      final toAdd = _plotRegionWithSyncedRect(region) ?? region;
      setState(() {
        _regions.add(toAdd);
        _activeRegionIndex = _regions.length - 1;
        _lineDraftPoints.clear();
        _lineDraftCurrent = null;
      });
      unawaited(_finalizeRegionNameForCurrentSelection());
      return;
    }

    if ((scenePoint - previous).distance < 12) {
      return;
    }
    setState(() {
      _lineDraftPoints.add(scenePoint);
      _lineDraftCurrent = scenePoint;
    });
  }

  void _zoomBy(double factor) {
    if (_isPdfFile && _pdfController != null) {
      _zoomPdfBy(factor);
      return;
    }
    final current = _viewerTransform.value;
    final currentScale = current.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(0.5, 8.0);
    final ratio = nextScale / currentScale;
    _viewerTransform.value = current.multiplied(
      Matrix4.identity()..scale(ratio),
    );
  }

  Offset _viewportCenter() {
    final box =
        _viewportCanvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.size.center(Offset.zero);
  }

  void _zoomPdfBy(double multiplier) {
    final ctrl = _pdfController;
    if (ctrl == null || !_isPdfFile) return;
    final viewportCenter = _viewportCenter();
    final scenePoint = MatrixUtils.transformPoint(
      Matrix4.inverted(ctrl.value),
      viewportCenter,
    );
    final current = ctrl.zoomRatio;
    final target = (current * multiplier).clamp(0.5, 8.0);
    final actualMult = target / current;
    if ((actualMult - 1).abs() < 0.001) return;
    final next = Matrix4.identity()
      ..translate(scenePoint.dx, scenePoint.dy)
      ..scale(actualMult)
      ..translate(-scenePoint.dx, -scenePoint.dy)
      ..multiply(ctrl.value);
    ctrl.goTo(destination: next, duration: const Duration(milliseconds: 160));
  }

  Future<void> _openEditLevelNameDialog() async {
    final controller = TextEditingController(
      text: _levelController.text.trim(),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Edit Level Name',
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          content: AppTextField(
            controller: controller,
            hintText: 'Enter level name',
            autofocus: true,
            fillColor: const Color(0xFFF3F3F4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    _scheduleDisposeTextControllersAfterRoute(<TextEditingController>[
      controller,
    ]);
    if (!mounted || value == null || value.trim().isEmpty) return;
    setState(() => _levelController.text = value.trim());
  }

  double _pinSizeForScreen(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    if (shortest < 360) return 28;
    if (shortest < 420) return 32;
    if (shortest < 600) return 36;
    return 42;
  }

  double _pinPointerHeightForScreen(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    if (shortest < 360) return 8;
    if (shortest < 420) return 9;
    if (shortest < 600) return 10;
    return 11;
  }

  Widget _actionCircle({
    required String iconAsset,
    bool active = false,
    VoidCallback? onTap,
    bool isDelete = false,
  }) {
    final bgColor = active ? const Color(0xFF111216) : const Color(0xFFF1F1F2);
    final borderColor = isDelete
        ? const Color(0xFFFFD8D8)
        : const Color(0xFFE4E4E6);
    final iconTint = isDelete
        ? AppColors.error
        : (active ? AppColors.white : AppColors.muted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Image.asset(
            iconAsset,
            width: 16,
            height: 16,
            color: iconTint,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim().isEmpty
        ? 'Ground Floor Plan'
        : widget.title;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        surfaceTintColor: const Color(0xFFF7F7F8),
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        titleSpacing: 0,

        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: _openEditLevelNameDialog,
            icon: const Icon(Icons.edit),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE3E3E5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _actionCircle(
                  iconAsset: AppImageString.shareIconPng,
                  active: _selectedTool == _CanvasTool.share,
                  onTap: () => _onToolSelected(_CanvasTool.share),
                ),
                const SizedBox(width: 14),
                _actionCircle(
                  iconAsset: AppImageString.pointIconPng,
                  active: _selectedTool == _CanvasTool.pin,
                  onTap: () => _onToolSelected(_CanvasTool.pin),
                ),
                const SizedBox(width: 14),
                _actionCircle(
                  iconAsset: AppImageString.selectAreaToolsIconPng,
                  active: _selectedTool == _CanvasTool.selectArea,
                  onTap: () => _onToolSelected(_CanvasTool.selectArea),
                ),
                const SizedBox(width: 14),
                _actionCircle(
                  iconAsset: AppImageString.lineSelectionIconPng,
                  active: _selectedTool == _CanvasTool.line,
                  onTap: () => _onToolSelected(_CanvasTool.line),
                ),
                const SizedBox(width: 14),
                _actionCircle(
                  iconAsset: AppImageString.locationIconPng,
                  active: _selectedTool == _CanvasTool.location,
                  onTap: () => _onToolSelected(_CanvasTool.location),
                ),
                const SizedBox(width: 14),
                _actionCircle(
                  iconAsset: AppImageString.deleteIconPng,
                  isDelete: true,
                  onTap: _onDeleteSelection,
                ),
              ],
            ),
          ),
          if (_uploadedPdfPaths.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _uploadedPdfPaths.map((path) {
                    final isActive = path == _activeFilePath;
                    final fileName = path.split(Platform.pathSeparator).last;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(fileName, overflow: TextOverflow.ellipsis),
                        selected: isActive,
                        onSelected: (_) => _switchActivePdf(path),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF3F3F4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _observeViewportGeometry(constraints.biggest);
                  return Stack(
                    children: [
                      Positioned.fill(
                        key: _viewportCanvasKey,
                        child: _usePdfViewport
                            ? _buildCanvasStack()
                            : InteractiveViewer(
                                transformationController: _viewerTransform,
                                minScale: 0.5,
                                maxScale: 8,
                                panEnabled: _canPanCanvas,
                                boundaryMargin: const EdgeInsets.all(80),
                                child: _buildCanvasStack(),
                              ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 74,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => _zoomBy(1.2),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE2E2E4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: AppColors.inkStrong,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _zoomBy(1 / 1.2),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE2E2E4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: AppColors.inkStrong,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7F8),
              border: Border(top: BorderSide(color: Color(0xFFE4E4E5))),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  AppTextField(
                    controller: _blockController,
                    hintText: 'Name :',
                    fillColor: const Color(0xFFF2F2F3),
                    borderRadius: 12,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _groupOptions.any((g) => g.id == _selectedGroupId)
                        ? _selectedGroupId
                        : null,
                    items: _groupOptions
                        .map(
                          (g) => DropdownMenuItem<int>(
                            value: g.id,
                            child: Text(g.name),
                          ),
                        )
                        .toList(),
                    onChanged: _isLoadingGroups
                        ? null
                        : (value) {
                            setState(() {
                              _selectedGroupId = value;
                              GroupItemOption? selected;
                              for (final g in _groupOptions) {
                                if (g.id == value) {
                                  selected = g;
                                  break;
                                }
                              }
                              _groupController.text = selected?.name ?? '';
                              _selectedCompositeItemId = null;
                              _productController.clear();
                            });
                            unawaited(_loadCompositeItemsForGroup(value));
                          },
                    decoration: InputDecoration(
                      hintText: _isLoadingGroups
                          ? 'Loading groups...'
                          : 'Group :',
                      filled: true,
                      fillColor: const Color(0xFFF2F2F3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0xFFE3E3E5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value:
                        _productOptions.any(
                          (item) => item.id == _selectedCompositeItemId,
                        )
                        ? _selectedCompositeItemId
                        : null,
                    items: _productOptions
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged:
                        (_selectedGroupId == null || _isLoadingCompositeItems)
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCompositeItemId = value;
                              CompositeItemOption? selected;
                              for (final item in _productOptions) {
                                if (item.id == value) {
                                  selected = item;
                                  break;
                                }
                              }
                              _productController.text = selected?.name ?? '';
                            });
                          },
                    decoration: InputDecoration(
                      hintText: _selectedGroupId == null
                          ? 'Select group first'
                          : (_isLoadingCompositeItems
                                ? 'Loading products...'
                                : 'Product :'),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0xFFE3E3E5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'VARIATION',
                        style: AppFonts.labelMedium(color: AppColors.inkStrong)
                            .copyWith(
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Spacer(),
                      CupertinoSwitch(
                        value: _variationOn,
                        onChanged: (v) => setState(() => _variationOn = v),
                        activeTrackColor: const Color(0xFF22C55E),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submitLevelPlots,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F1013),
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting ? 'Saving...' : 'Submit',
                        style: AppFonts.titleSmall(
                          color: AppColors.white,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CanvasTool { share, pin, selectArea, line, location }

class PinView extends StatelessWidget {
  const PinView({
    super.key,
    required this.number,
    this.size = 32,
    this.pointerHeight = 9,
  });

  final int number;
  final double size;
  final double pointerHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              color: const Color(0xFF111216),
              border: Border.all(color: Colors.white, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: AppFonts.labelMedium(
                color: AppColors.white,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: size * 0.35),
            ),
          ),
          Positioned(
            left: size / 2 - pointerHeight * 0.75,
            top: size - 1,
            child: CustomPaint(
              size: Size(pointerHeight * 1.5, pointerHeight),
              painter: _PinTrianglePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF111216);
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
    if (corners != null &&
        corners.length >= 2 &&
        crossPaint != null) {
      final crossStroke = Paint()
        ..color = crossPaint
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final center = _polygonCentroid(corners);
      for (final corner in corners) {
        _paintDashedLine(
          canvas,
          center,
          corner,
          crossStroke,
          crossDashPattern,
        );
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

class _PlotRegion {
  _PlotRegion({
    required this.rect,
    required this.name,
    required this.pins,
    this.lines,
    this.serverPlotId,
    this.pdfAnchorA,
    this.pdfAnchorB,
    this.pdfVertices,
  });

  final Rect rect;
  final String? name;
  final List<_CanvasPin> pins;
  final List<_CanvasLine>? lines;
  final int? serverPlotId;

  /// PDF-space corners for box plots (survives zoom on PDF).
  PdfAnnotationPoint? pdfAnchorA;
  PdfAnnotationPoint? pdfAnchorB;
  List<PdfAnnotationPoint>? pdfVertices;

  List<_CanvasLine> get safeLines => lines ?? const <_CanvasLine>[];

  _PlotRegion copyWith({
    Rect? rect,
    String? name,
    List<_CanvasPin>? pins,
    List<_CanvasLine>? lines,
    int? serverPlotId,
    PdfAnnotationPoint? pdfAnchorA,
    PdfAnnotationPoint? pdfAnchorB,
    List<PdfAnnotationPoint>? pdfVertices,
  }) {
    return _PlotRegion(
      rect: rect ?? this.rect,
      name: name ?? this.name,
      pins: pins ?? this.pins,
      lines: lines ?? this.lines ?? const <_CanvasLine>[],
      serverPlotId: serverPlotId ?? this.serverPlotId,
      pdfAnchorA: pdfAnchorA ?? this.pdfAnchorA,
      pdfAnchorB: pdfAnchorB ?? this.pdfAnchorB,
      pdfVertices: pdfVertices ?? this.pdfVertices,
    );
  }
}

class _CanvasLine {
  const _CanvasLine({required this.start, required this.end});

  final Offset start;
  final Offset end;
}

class _CanvasPin {
  const _CanvasPin({
    required this.offset,
    this.pdfPoint,
    required this.productName,
    required this.status,
    this.statusId,
    this.groupId,
    this.compositeItemId,
    required this.quantity,
    required this.blockName,
    required this.levelName,
    required this.zoneName,
    required this.variation,
    required this.droppedAt,
    required this.description,
    this.serverPinId,
  });

  final Offset offset;

  /// True PDF user-space position; source of truth on PDF (not screen pixels).
  final PdfAnnotationPoint? pdfPoint;

  final String productName;
  final String status;
  final int? statusId;
  final int? groupId;
  final int? compositeItemId;
  final int quantity;
  final String blockName;
  final String levelName;
  final String zoneName;
  final String variation;
  final DateTime droppedAt;
  final String description;
  final int? serverPinId;

  _CanvasPin copyWith({
    Offset? offset,
    PdfAnnotationPoint? pdfPoint,
    String? productName,
    String? status,
    int? statusId,
    int? groupId,
    int? compositeItemId,
    int? quantity,
    String? blockName,
    String? levelName,
    String? zoneName,
    String? variation,
    DateTime? droppedAt,
    String? description,
    int? serverPinId,
  }) {
    return _CanvasPin(
      offset: offset ?? this.offset,
      pdfPoint: pdfPoint ?? this.pdfPoint,
      productName: productName ?? this.productName,
      status: status ?? this.status,
      statusId: statusId ?? this.statusId,
      groupId: groupId ?? this.groupId,
      compositeItemId: compositeItemId ?? this.compositeItemId,
      quantity: quantity ?? this.quantity,
      blockName: blockName ?? this.blockName,
      levelName: levelName ?? this.levelName,
      zoneName: zoneName ?? this.zoneName,
      variation: variation ?? this.variation,
      droppedAt: droppedAt ?? this.droppedAt,
      description: description ?? this.description,
      serverPinId: serverPinId ?? this.serverPinId,
    );
  }
}

class _PinHit {
  const _PinHit({required this.regionIndex, required this.pinIndex});

  final int regionIndex;
  final int pinIndex;
}

class _PinSheetResult {
  const _PinSheetResult({this.updatedPin, this.removePin = false});

  final _CanvasPin? updatedPin;
  final bool removePin;
}

class _PinDetailBottomSheet extends StatefulWidget {
  const _PinDetailBottomSheet({
    required this.pinNumber,
    required this.pin,
    required this.pinStatuses,
    required this.onCreatePinStatus,
    required this.onEditPinStatus,
  });

  final int pinNumber;
  final _CanvasPin pin;
  final List<PinStatusItem> pinStatuses;
  final Future<PinStatusItem?> Function() onCreatePinStatus;
  final Future<PinStatusItem?> Function(PinStatusItem) onEditPinStatus;

  @override
  State<_PinDetailBottomSheet> createState() => _PinDetailBottomSheetState();
}

class _PinDetailBottomSheetState extends State<_PinDetailBottomSheet> {
  late final TextEditingController _productController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _qtyController;
  late final TextEditingController _blockController;
  late final TextEditingController _levelController;
  late final TextEditingController _zoneController;
  late String _status;
  late String _variation;
  bool _isEditing = false;
  late List<PinStatusItem> _pinStatusCatalog;

  static const List<String> _fallbackStatuses = <String>[
    'To Do',
    'In Progress',
    'Inactive',
    'Installed',
    'Action Required',
  ];
  static const List<String> _variationOptions = <String>['No', 'Yes'];
  late List<String> _statusOptions;

  @override
  void initState() {
    super.initState();
    _pinStatusCatalog = List<PinStatusItem>.from(widget.pinStatuses);
    _productController = TextEditingController(text: widget.pin.productName);
    _descriptionController = TextEditingController(
      text: widget.pin.description,
    );
    _qtyController = TextEditingController(text: '${widget.pin.quantity}');
    _blockController = TextEditingController(text: widget.pin.blockName);
    _levelController = TextEditingController(text: widget.pin.levelName);
    _zoneController = TextEditingController(text: widget.pin.zoneName);
    _statusOptions = _pinStatusCatalog
        .map((e) => e.statusName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (_statusOptions.isEmpty) {
      _statusOptions = List<String>.from(_fallbackStatuses);
    }
    _status = _statusOptions.contains(widget.pin.status)
        ? widget.pin.status
        : _statusOptions.first;
    _variation = _variationOptions.contains(widget.pin.variation)
        ? widget.pin.variation
        : _variationOptions.first;
  }

  @override
  void didUpdateWidget(covariant _PinDetailBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinStatuses != oldWidget.pinStatuses) {
      _pinStatusCatalog = List<PinStatusItem>.from(widget.pinStatuses);
      final names = _pinStatusCatalog
          .map((e) => e.statusName.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (names.isNotEmpty) {
        _statusOptions = names;
      }
      if (!_statusOptions.contains(_status)) {
        _status = _statusOptions.isNotEmpty
            ? _statusOptions.first
            : widget.pin.status;
      }
    }
  }

  @override
  void dispose() {
    _productController.dispose();
    _descriptionController.dispose();
    _qtyController.dispose();
    _blockController.dispose();
    _levelController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  void _resetForm() {
    final pin = widget.pin;
    _productController.text = pin.productName;
    _descriptionController.text = pin.description;
    _qtyController.text = '${pin.quantity}';
    _blockController.text = pin.blockName;
    _levelController.text = pin.levelName;
    _zoneController.text = pin.zoneName;
    _status = _statusOptions.contains(pin.status)
        ? pin.status
        : _statusOptions.first;
    _variation = _variationOptions.contains(pin.variation)
        ? pin.variation
        : _variationOptions.first;
  }

  int? _statusIdByNameLocal(String statusName) {
    final normalized = statusName.trim().toLowerCase();
    for (final s in _pinStatusCatalog) {
      if (s.statusName.trim().toLowerCase() == normalized) {
        return int.tryParse(s.id);
      }
    }
    return null;
  }

  PinStatusItem? _statusItemByNameLocal(String statusName) {
    final normalized = statusName.trim().toLowerCase();
    for (final s in _pinStatusCatalog) {
      if (s.statusName.trim().toLowerCase() == normalized) {
        return s;
      }
    }
    return null;
  }

  String _fmt(DateTime d) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} $h:$m:$s';
  }

  Widget _sheetGrabHandle() {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9DA),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  TextStyle get _sheetCapsLabelStyle => AppFonts.labelMedium(
    color: AppColors.muted,
  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6, fontSize: 11);

  Widget _sheetFieldLabel(String text) {
    return Text(text.toUpperCase(), style: _sheetCapsLabelStyle);
  }

  Widget _viewMetaCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _sheetCapsLabelStyle),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }

  Widget _viewStatusPill() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFECECED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E0E2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _status,
              style: AppFonts.titleSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B6B70),
            size: 26,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildViewModeChildren(_CanvasPin pin) {
    final productTitle = _productController.text.trim().isEmpty
        ? 'Pin ${widget.pinNumber}'
        : _productController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim()) ?? pin.quantity;
    return [
      _sheetGrabHandle(),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Location ${widget.pinNumber}',
              style: AppFonts.titleMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          Material(
            color: const Color(0xFFEDEDEF),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _isEditing = true),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.inkStrong,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        productTitle,
        style: AppFonts.headlineSmall(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 22, height: 1.2),
      ),
      const SizedBox(height: 6),
      Text(
        'Qty: $qty',
        style: AppFonts.bodyMedium(
          color: AppColors.muted,
        ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      const SizedBox(height: 16),
      _viewStatusPill(),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE3E3E5)),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _viewMetaCell('BLOCK', _blockController.text.trim())),
          const SizedBox(width: 16),
          Expanded(child: _viewMetaCell('LEVEL', _levelController.text.trim())),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _viewMetaCell('ZONE', _zoneController.text.trim())),
          const SizedBox(width: 16),
          Expanded(child: _viewMetaCell('VARIATION', _variation)),
        ],
      ),
      const SizedBox(height: 16),
      _viewMetaCell('DROPPED', _fmt(pin.droppedAt)),
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 12),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE3E3E5)),
      ),
      Text('DESCRIPTION', style: _sheetCapsLabelStyle),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _descriptionController.text.trim().isEmpty
              ? '—'
              : _descriptionController.text.trim(),
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(height: 1.45, fontWeight: FontWeight.w500),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF14141),
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () =>
              Navigator.of(context).pop(const _PinSheetResult(removePin: true)),
          child: Text(
            'Remove This Pin',
            style: AppFonts.titleMedium(
              color: AppColors.white,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ];
  }

  Widget _editTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int? minLines,
    int? maxLines,
  }) {
    return AppTextField(
      controller: controller,
      hintText: hint,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      fillColor: const Color(0xFFF3F3F4),
      borderRadius: 12,
    );
  }

  List<Widget> _buildEditModeChildren(_CanvasPin pin) {
    return [
      _sheetGrabHandle(),
      const SizedBox(height: 8),
      Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 22),
            color: AppColors.inkStrong,
            splashRadius: 22,
          ),
          Expanded(
            child: Text(
              'Edit Pin',
              textAlign: TextAlign.center,
              style: AppFonts.titleMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _resetForm();
                _isEditing = false;
              });
            },
            child: Text(
              'RESET',
              style: AppFonts.labelMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      const Divider(height: 1, thickness: 1, color: Color(0xFFE3E3E5)),
      const SizedBox(height: 16),
      _sheetFieldLabel('Product name'),
      const SizedBox(height: 6),
      _editTextField(controller: _productController, hint: 'Product name'),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Quantity'),
                const SizedBox(height: 6),
                _editTextField(
                  controller: _qtyController,
                  hint: '1',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Status'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _statusOptions.contains(_status)
                      ? _status
                      : _statusOptions.first,
                  items: _statusOptions
                      .map(
                        (s) =>
                            DropdownMenuItem<String>(value: s, child: Text(s)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFFF3F3F4),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Color(0xFFE3E3E5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Block'),
                const SizedBox(height: 6),
                _editTextField(controller: _blockController, hint: 'Block'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Level'),
                const SizedBox(height: 6),
                _editTextField(controller: _levelController, hint: 'Level'),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Zone'),
                const SizedBox(height: 6),
                _editTextField(controller: _zoneController, hint: 'Zone'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Variation'),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoSwitch(
                    value: _variation == 'Yes',
                    onChanged: (v) =>
                        setState(() => _variation = v ? 'Yes' : 'No'),
                    activeTrackColor: const Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _sheetFieldLabel('Dropped'),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3E3E5)),
        ),
        child: Text(
          _fmt(pin.droppedAt),
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      const SizedBox(height: 18),
      _sheetFieldLabel('Description'),
      const SizedBox(height: 6),
      _editTextField(
        controller: _descriptionController,
        hint: 'Description',
        minLines: 3,
        maxLines: 6,
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF090A0D),
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            final qty =
                int.tryParse(_qtyController.text.trim()) ?? pin.quantity;
            Navigator.of(context).pop(
              _PinSheetResult(
                updatedPin: pin.copyWith(
                  productName: _productController.text.trim(),
                  quantity: qty < 1 ? 1 : qty,
                  status: _status,
                  statusId: _statusIdByNameLocal(_status),
                  blockName: _blockController.text.trim(),
                  levelName: _levelController.text.trim(),
                  zoneName: _zoneController.text.trim(),
                  variation: _variation,
                  description: _descriptionController.text.trim(),
                ),
              ),
            );
          },
          child: Text(
            'SAVE CHANGES',
            style: AppFonts.titleSmall(
              color: AppColors.white,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _resetForm();
              _isEditing = false;
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.inkStrong,
            side: const BorderSide(color: Color(0xFFD9D9DC)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'CANCEL',
            style: AppFonts.titleSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: _isEditing
                  ? _buildEditModeChildren(pin)
                  : _buildViewModeChildren(pin),
            );
          },
        ),
      ),
    );
  }
}

class _PlotNameBottomSheetBody extends StatefulWidget {
  const _PlotNameBottomSheetBody();

  @override
  State<_PlotNameBottomSheetBody> createState() =>
      _PlotNameBottomSheetBodyState();
}

class _PlotNameBottomSheetBodyState extends State<_PlotNameBottomSheetBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _controller.text.trim().isNotEmpty;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9DA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'New Plot Name',
                  style: AppFonts.headlineSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  'PLOT LABEL',
                  style: AppFonts.labelMedium(
                    color: AppColors.muted,
                  ).copyWith(letterSpacing: 1.8, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _controller,
                  hintText: 'Enter plot name...',
                  autofocus: true,
                  fillColor: const Color(0xFFF4F4F5),
                  borderRadius: 12,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: canContinue
                        ? () =>
                              Navigator.of(context).pop(_controller.text.trim())
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF070A0E),
                      disabledBackgroundColor: const Color(0xFFB4B4B7),
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: AppFonts.titleMedium(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppFonts.titleMedium(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
