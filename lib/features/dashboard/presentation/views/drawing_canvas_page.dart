import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/network/api_int_parsing.dart';
import 'package:red5/core/navigation/safe_overlay_pop.dart';
import 'package:red5/core/utils/text_controller_lifecycle.dart';
import 'package:red5/core/pdf_coordinates/pdf_coordinates.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_feature_flags.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/dashboard/presentation/widgets/pin_status_delete_dialog.dart';
import 'package:red5/features/dashboard/presentation/widgets/pin_status_form_sheet.dart';
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
  final Map<int, String> _abbreviationByCompositeItemId = <int, String>{};
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
  int? _selectedPinRegionIndex;
  int? _selectedPinIndex;
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
  bool get _blockPdfGestures => _usePdfViewport && !_pdfViewerHandlesGestures;

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
    } else {
      final fallbackTitle = widget.title.trim();
      if (fallbackTitle.isNotEmpty) {
        _blockController.text = fallbackTitle;
      }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _loadSavedLevelMarkup();
        if (!mounted) return;
        _realignMarkupFromApiSources();
        if (_isPdfFile && _pdfController != null) {
          setState(() {});
        }
      });
    });
  }

  /// Re-applies plot/pin positions after the letterboxed content rect is known.
  void _realignMarkupFromApiSources() {
    if (!_hasFile || _regions.isEmpty) return;
    setState(() {
      _regions.setAll(
        0,
        _regions
            .map((region) {
              var next = region;
              final raw = region.apiCoordinatesRaw;
              if (raw != null && !_usePdfViewport) {
                final pts = _pointsFromCoordinates(raw);
                if (pts.length >= 2) {
                  final shapeLines = pts.length >= 3
                      ? _linesFromCoordinatePoints(pts)
                      : const <_CanvasLine>[];
                  final rect = _rectFromCoordinatePoints(pts) ?? region.rect;
                  next = region.copyWith(rect: rect, lines: shapeLines);
                  next = _plotRegionWithSyncedRect(next) ?? next;
                }
              }
              final pins = next.pins
                  .map((pin) {
                    if (_usePdfViewport) {
                      if (pin.pdfPoint != null) {
                        return pin.copyWith(offset: _pinAnchorScene(pin));
                      }
                      return pin;
                    }
                    if (pin.contentNormX == null || pin.contentNormY == null) {
                      return pin;
                    }
                    return pin.copyWith(
                      offset: _denormalizeScenePoint(
                        pin.contentNormX!,
                        pin.contentNormY!,
                      ),
                    );
                  })
                  .toList(growable: false);
              return next.copyWith(pins: pins);
            })
            .toList(growable: false),
      );
    });
  }

  void _initPdfControllerForActivePath() {
    final path = (_activeFilePath ?? '').trim();
    if (path.isEmpty || !File(path).existsSync()) return;
    if (!path.toLowerCase().endsWith('.pdf')) return;
    _detachPdfController();
    final controller = PdfControllerPinch(document: PdfDocument.openFile(path));
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
    _pdfController?.dispose();
    _pdfController = null;
    _pdfMetadataCache = null;
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

  Size? _viewportCanvasSize() {
    final box =
        _viewportCanvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.size;
  }

  /// Pins extend above [anchor]; hide when the glyph would leave the PDF viewport.
  bool _shouldPaintPinAt(
    Offset anchor, {
    required double pinSize,
    required double pointerH,
  }) {
    final viewport = _viewportCanvasSize();
    if (viewport == null) return true;
    final top = anchor.dy - pinSize - pointerH;
    if (top < 0 || anchor.dy > viewport.height + 2) return false;
    if (anchor.dx < -pinSize || anchor.dx > viewport.width + pinSize) {
      return false;
    }
    return true;
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
            pendingDeletedPinIds: Set<int>.from(r.pendingDeletedPinIds),
          ),
        )
        .toList();
  }

  void _clearPendingDeletedPinIds() {
    for (var i = 0; i < _regions.length; i++) {
      if (_regions[i].pendingDeletedPinIds.isEmpty) continue;
      _regions[i] = _regions[i].copyWith(pendingDeletedPinIds: const <int>{});
    }
  }

  void _logLevelPlotsSyncResult(Map<String, dynamic>? responseBody) {
    if (!kDebugMode || responseBody == null) return;
    final plots = QuoteProjectApiClient.plotsFromLevelResponse(responseBody);
    for (final plot in plots) {
      final plotId = readApiIntFromMap(plot, const ['id', 'plot_id']);
      final pinsRaw = plot['pins'];
      final pinCount = pinsRaw is List ? pinsRaw.length : 0;
      final deleted = QuoteProjectApiClient.deletedPinIdsFromPlotPayload(plot);
      debugPrint(
        '[DrawingCanvas] plot id=$plotId pins=$pinCount '
        'deleted_pin_ids=$deleted',
      );
    }
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
    scheduleDisposeTextControllers(controllers);
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
    if (_usePdfViewport) {
      final size = _canvasSceneSizeForNormalization();
      return Rect.fromLTWH(0, 0, size.width, size.height);
    }
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
                final mappedPins = region.pins
                    .map((pin) {
                      if (_usePdfViewport && pin.pdfPoint != null) {
                        final scene = _pinAnchorScene(pin);
                        return pin.copyWith(offset: scene);
                      }
                      if (pin.contentNormX != null &&
                          pin.contentNormY != null) {
                        return pin.copyWith(
                          offset: _denormalizeScenePoint(
                            pin.contentNormX!,
                            pin.contentNormY!,
                          ),
                        );
                      }
                      return pin.copyWith(
                        offset: _mapPointAcrossContentRects(
                          pin.offset,
                          qFrom,
                          qTo,
                        ),
                      );
                    })
                    .toList(growable: false);
                _PlotRegion remapped = region;
                if (region.apiCoordinatesRaw != null && !_usePdfViewport) {
                  final pts = _pointsFromCoordinates(region.apiCoordinatesRaw);
                  if (pts.length >= 2) {
                    final shapeLines = pts.length >= 3
                        ? _linesFromCoordinatePoints(pts)
                        : const <_CanvasLine>[];
                    final rect = _rectFromCoordinatePoints(pts) ?? region.rect;
                    remapped = region.copyWith(rect: rect, lines: shapeLines);
                    remapped = _plotRegionWithSyncedRect(remapped) ?? remapped;
                  }
                } else {
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
                  remapped = region.copyWith(
                    rect: mappedRect,
                    lines: mappedLines,
                  );
                }
                return remapped.copyWith(pins: mappedPins);
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

  /// Whether the API/website expects a rotated (landscape) coordinate frame.
  ///
  /// Only applies to **PDF** levels. Raster screenshots/images use plain 0–100%
  /// of the image (same as the website canvas) — no portrait↔landscape swap.
  bool get _shouldApplyLandscapeRotation {
    if (!_isPdfFile || _usePdfViewport) return false;
    final ratio = _activeContentAspectRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) return false;
    return ratio < 1.0;
  }

  /// API x/y (0–1 or 0–100) → portrait-normalized fractions in the content rect.
  Offset _apiPortraitNormFromRaw(double x, double y) {
    final nx = PdfCoordinateCodec.normalizeApiScalar(x);
    final ny = PdfCoordinateCodec.normalizeApiScalar(y);
    return _landscapeApiToPortraitNorm(Offset(nx, ny));
  }

  Offset _scenePointFromApiCoordinates(double x, double y) {
    final norm = _apiPortraitNormFromRaw(x, y);
    return _denormalizeScenePoint(norm.dx, norm.dy);
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
    return _scenePointFromApiCoordinates(x, y);
  }

  void _applyPinScenePosition(_PinHit hit, Offset scene) {
    if (hit.regionIndex < 0 || hit.regionIndex >= _regions.length) return;
    final region = _regions[hit.regionIndex];
    final bounds = _regionSceneRect(region);
    final clamped = Offset(
      scene.dx.clamp(bounds.left, bounds.right),
      scene.dy.clamp(bounds.top, bounds.bottom),
    );
    if (!_regionContainsPoint(region, clamped)) return;
    if (hit.pinIndex < 0 || hit.pinIndex >= region.pins.length) return;
    final engine = _pdfEngine;
    final pdfPoint = engine?.viewportToAnnotation(clamped);
    final contentNorm = _normalizeScenePoint(clamped);
    setState(() {
      final pins = List<_CanvasPin>.from(region.pins);
      pins[hit.pinIndex] = pins[hit.pinIndex].copyWith(
        offset: clamped,
        contentNormX: contentNorm.dx,
        contentNormY: contentNorm.dy,
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

  /// Avoids Navigator `!_debugLocked` when closing dialogs from button handlers.
  void _popDialogSafely<T>(BuildContext dialogContext, [T? result]) {
    popOverlaySafely<T>(dialogContext, result);
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
            'This removes all selected areas, pins, and lines from this level '
            'and updates the server.',
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => _popDialogSafely<bool>(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF14141),
                foregroundColor: AppColors.white,
              ),
              onPressed: () => _popDialogSafely<bool>(ctx, true),
              child: const Text('Remove All'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) return;
    _clearAllCanvasMarkup();
    await _submitLevelPlots(clearAllOnServer: true, popOnSuccess: false);
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
    return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
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

  void _assignPdfVerticesForPoints(
    _PlotRegion region,
    List<Offset> scenePoints,
  ) {
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

  bool _plotRegionIsNamed(_PlotRegion region) =>
      (region.name ?? '').trim().isNotEmpty;

  static const String _plotOverlapMessage =
      'This box overlaps with an existing plot';

  bool _plotOverlapsAnyExistingNamedPlot(
    _PlotRegion candidate, {
    int? ignoreIndex,
  }) {
    final candidatePath = _regionPath(candidate);
    final candidateBounds = candidatePath.getBounds();
    if (candidateBounds.width <= 0 || candidateBounds.height <= 0) {
      return false;
    }
    final candidateCenter = _regionSceneRect(candidate).center;

    for (var i = 0; i < _regions.length; i++) {
      if (i == ignoreIndex) continue;
      final existing = _regions[i];
      if (!_plotRegionIsNamed(existing)) continue;

      final existingPath = _regionPath(existing);
      final existingBounds = existingPath.getBounds();
      if (!candidateBounds.overlaps(existingBounds)) continue;

      if (_plotShapesOverlap(
        candidatePath: candidatePath,
        candidate: candidate,
        existingPath: existingPath,
        existing: existing,
        candidateCenter: candidateCenter,
      )) {
        return true;
      }
    }
    return false;
  }

  bool _plotShapesOverlap({
    required Path candidatePath,
    required _PlotRegion candidate,
    required Path existingPath,
    required _PlotRegion existing,
    required Offset candidateCenter,
  }) {
    if (existingPath.contains(candidateCenter)) return true;
    if (candidatePath.contains(_regionSceneRect(existing).center)) return true;

    for (final p in _regionScenePolygonPoints(candidate)) {
      if (existingPath.contains(p)) return true;
    }
    for (final p in _regionScenePolygonPoints(existing)) {
      if (candidatePath.contains(p)) return true;
    }

    final intersection = candidatePath.getBounds().intersect(
      existingPath.getBounds(),
    );
    return intersection.width > 4 && intersection.height > 4;
  }

  bool _pointInsideAnyNamedPlot(Offset point) {
    for (var i = _regions.length - 1; i >= 0; i--) {
      if (!_plotRegionIsNamed(_regions[i])) continue;
      if (_regionContainsPoint(_regions[i], point)) return true;
    }
    return false;
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

  void _adjustActiveRegionIndexAfterRemoval(int removedIndex) {
    final active = _activeRegionIndex;
    if (active == null) return;
    if (active == removedIndex) {
      _activeRegionIndex = _regions.isEmpty
          ? null
          : math.min(removedIndex, _regions.length - 1);
    } else if (active > removedIndex) {
      _activeRegionIndex = active - 1;
    }
  }

  /// Shows [prepared] on canvas, prompts for a name; cancel removes the preview plot.
  Future<void> _commitNewPlotRegion(_PlotRegion prepared) async {
    late final int pendingIndex;
    setState(() {
      _regions.add(prepared);
      pendingIndex = _regions.length - 1;
      _activeRegionIndex = pendingIndex;
    });
    final name = await _showPlotNameBottomSheet();
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) {
      setState(() {
        if (pendingIndex >= 0 && pendingIndex < _regions.length) {
          _regions.removeAt(pendingIndex);
          _adjustActiveRegionIndexAfterRemoval(pendingIndex);
        }
      });
      return;
    }
    setState(() {
      if (pendingIndex >= 0 && pendingIndex < _regions.length) {
        _regions[pendingIndex] = _regions[pendingIndex].copyWith(
          name: name.trim(),
        );
        _activeRegionIndex = pendingIndex;
      }
    });
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
      locked: true,
    );
    _assignPdfAnchorsForRect(region, rect);
    final prepared = _plotRegionWithSyncedRect(region) ?? region;
    setState(() {
      _draftStart = null;
      _draftCurrent = null;
    });
    if (_plotOverlapsAnyExistingNamedPlot(prepared)) {
      _showTopToast(_plotOverlapMessage);
      return;
    }
    await _commitNewPlotRegion(prepared);
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
    if (!_regions.any(_plotRegionIsNamed)) {
      _showTopToast('Select an area first');
      return;
    }
    final p = scenePoint;
    int? targetIndex;
    for (var i = _regions.length - 1; i >= 0; i--) {
      if (!_plotRegionIsNamed(_regions[i])) continue;
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
    final abbreviation = (() {
      final fromSelected = _abbreviationForCompositeItem(selectedCompositeItemId);
      if (fromSelected.isNotEmpty) return fromSelected;
      return _abbreviationFromLabel(product);
    })();
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
      final contentNorm = _normalizeScenePoint(p);
      final nextPins = List<_CanvasPin>.from(region.pins)
        ..add(
          _CanvasPin(
            offset: p,
            contentNormX: contentNorm.dx,
            contentNormY: contentNorm.dy,
            pdfPoint: pdfPoint,
            productName: product,
            abbreviation: abbreviation,
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
      if (!_plotRegionIsNamed(_regions[i])) continue;
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
    setState(() {
      _selectedPinRegionIndex = regionIndex;
      _selectedPinIndex = pinIndex;
    });

    final result = await showModalBottomSheet<_PinSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => _PinDetailBottomSheet(
        pinNumber: pinIndex + 1,
        pin: currentPin,
        pinStatuses: _pinStatuses,
        onCreatePinStatus: _createPinStatus,
        onEditPinStatus: _editPinStatus,
        onDeletePinStatus: _deletePinStatus,
        levelId: _levelId,
        levelLabel: _levelController.text.trim(),
      ),
    );
    unfocusPrimary();
    if (!mounted || result == null) return;
    if (result.removePin) {
      final removedPin = currentPin;
      setState(() {
        final livePins = List<_CanvasPin>.from(_regions[regionIndex].pins);
        final liveIndex = _resolveLivePinIndex(
          pins: livePins,
          fallbackIndex: pinIndex,
          snapshotPin: currentPin,
        );
        if (liveIndex < 0 || liveIndex >= livePins.length) {
          _showTopToast('Pin no longer available.');
          return;
        }
        final nextPins = List<_CanvasPin>.from(livePins)..removeAt(liveIndex);
        final pending = Set<int>.from(
          _regions[regionIndex].pendingDeletedPinIds,
        );
        final deletedId = removedPin.serverPinId;
        if (deletedId != null) pending.add(deletedId);
        _regions[regionIndex] = _regions[regionIndex].copyWith(
          pins: nextPins,
          pendingDeletedPinIds: pending,
        );
        _selectedPinRegionIndex = null;
        _selectedPinIndex = null;
      });
      await _submitLevelPlots(popOnSuccess: false);
      return;
    }
    final updated = result.updatedPin;
    if (updated == null) return;
    setState(() {
      final nextPins = List<_CanvasPin>.from(_regions[regionIndex].pins);
      final liveIndex = _resolveLivePinIndex(
        pins: nextPins,
        fallbackIndex: pinIndex,
        snapshotPin: currentPin,
      );
      if (liveIndex < 0 || liveIndex >= nextPins.length) return;
      nextPins[liveIndex] = updated;
      _regions[regionIndex] = _regions[regionIndex].copyWith(pins: nextPins);
      _selectedPinRegionIndex = regionIndex;
      _selectedPinIndex = liveIndex;
    });
    await _submitLevelPlots(popOnSuccess: false);
  }

  int _resolveLivePinIndex({
    required List<_CanvasPin> pins,
    required int fallbackIndex,
    required _CanvasPin snapshotPin,
  }) {
    if (pins.isEmpty) return -1;
    final serverPinId = snapshotPin.serverPinId;
    if (serverPinId != null) {
      for (var i = 0; i < pins.length; i++) {
        if (pins[i].serverPinId == serverPinId) return i;
      }
    }
    if (fallbackIndex >= 0 && fallbackIndex < pins.length) {
      final byIndex = pins[fallbackIndex];
      if (identical(byIndex, snapshotPin)) return fallbackIndex;
      final sameCore =
          byIndex.compositeItemId == snapshotPin.compositeItemId &&
          byIndex.groupId == snapshotPin.groupId &&
          (byIndex.offset - snapshotPin.offset).distance <= 0.5;
      if (sameCore) return fallbackIndex;
    }
    for (var i = 0; i < pins.length; i++) {
      final candidate = pins[i];
      final sameCore =
          candidate.compositeItemId == snapshotPin.compositeItemId &&
          candidate.groupId == snapshotPin.groupId &&
          (candidate.offset - snapshotPin.offset).distance <= 0.5;
      if (sameCore) return i;
    }
    return fallbackIndex;
  }

  Future<void> _loadPinStatuses() async {
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final statuses = await api.fetchPinStatuses(isActive: true);
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
        } else if (_selectedGroupId != null &&
            _groupController.text.trim().isEmpty) {
          for (final g in _groupOptions) {
            if (g.id == _selectedGroupId) {
              _groupController.text = g.name;
              break;
            }
          }
        }
      });
      unawaited(_restoreGroupProductSelectionFromLoadedPins());
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
        _cacheCompositeItemAbbreviations(products);
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

  void _cacheCompositeItemAbbreviations(List<CompositeItemOption> products) {
    for (final product in products) {
      final abbr = product.abbreviation.trim();
      if (abbr.isNotEmpty) {
        _abbreviationByCompositeItemId[product.id] = abbr;
      }
    }
  }

  String _abbreviationForCompositeItem(int? compositeItemId) {
    if (compositeItemId == null) return '';
    for (final product in _productOptions) {
      if (product.id == compositeItemId) {
        return product.abbreviation.trim();
      }
    }
    return _abbreviationByCompositeItemId[compositeItemId]?.trim() ?? '';
  }

  String _abbreviationFromLabel(String label) {
    return label
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(3)
        .map((w) => w[0].toUpperCase())
        .join();
  }

  String _pinDisplayAbbreviation(_CanvasPin pin) {
    final stored = pin.abbreviation.trim();
    if (stored.isNotEmpty) return stored;
    final byItem = _abbreviationForCompositeItem(pin.compositeItemId);
    if (byItem.isNotEmpty) return byItem;
    return _abbreviationFromLabel(pin.productName);
  }

  Future<void> _hydratePinAbbreviationsForLoadedPlots() async {
    final groupIds = <int>{};
    for (final region in _regions) {
      for (final pin in region.pins) {
        if (pin.abbreviation.trim().isNotEmpty) continue;
        final gid = pin.groupId;
        if (gid != null) groupIds.add(gid);
      }
    }
    if (groupIds.isEmpty) return;
    final api = ref.read(quoteProjectApiClientProvider);
    for (final groupId in groupIds) {
      try {
        final products = await api.fetchCompositeItems(groupId: groupId);
        _cacheCompositeItemAbbreviations(products);
      } catch (_) {
        // Abbreviations are cosmetic; ignore lookup failures.
      }
    }
    if (!mounted) return;
    var changed = false;
    final nextRegions = <_PlotRegion>[];
    for (final region in _regions) {
      var regionChanged = false;
      final nextPins = <_CanvasPin>[];
      for (final pin in region.pins) {
        if (pin.abbreviation.trim().isNotEmpty) {
          nextPins.add(pin);
          continue;
        }
        final abbr = _abbreviationForCompositeItem(pin.compositeItemId);
        if (abbr.isEmpty) {
          nextPins.add(pin);
          continue;
        }
        regionChanged = true;
        changed = true;
        nextPins.add(pin.copyWith(abbreviation: abbr));
      }
      nextRegions.add(regionChanged ? region.copyWith(pins: nextPins) : region);
    }
    if (!changed || !mounted) return;
    setState(() {
      _regions
        ..clear()
        ..addAll(nextRegions);
      final k = (_activeFilePath ?? '').trim();
      if (k.isNotEmpty) {
        _regionsByPdfPath[k] = _snapshotRegions(_regions);
      }
    });
  }

  Future<PinStatusItem?> _createPinStatus() async {
    PinStatusItem? created;
    await showPinStatusFormSheet(
      context: context,
      ref: ref,
      onSaved: (saved) async {
        created = saved;
        await _loadPinStatuses();
      },
      onMessage: _showTopToast,
    );
    return created;
  }

  Future<PinStatusItem?> _editPinStatus(PinStatusItem source) async {
    PinStatusItem editing = source;
    try {
      editing = await ref
          .read(quoteProjectApiClientProvider)
          .fetchPinStatusById(source.id);
    } catch (_) {
      // Use cached row if read fails.
    }
    PinStatusItem? updated;
    await showPinStatusFormSheet(
      context: context,
      ref: ref,
      editing: editing,
      onSaved: (saved) async {
        updated = saved;
        await _loadPinStatuses();
      },
      onMessage: _showTopToast,
    );
    return updated;
  }

  Future<bool> _deletePinStatus(PinStatusItem item) async {
    final request = await showPinStatusDeleteDialog(
      context: context,
      item: item,
      allStatuses: _pinStatuses,
    );
    if (request == null || !mounted) return false;
    try {
      await ref
          .read(quoteProjectApiClientProvider)
          .deletePinStatus(item.id, moveToStatusId: request.moveToStatusId);
      if (!mounted) return false;
      await _loadPinStatuses();
      _showTopToast('Status deleted');
      return true;
    } catch (e) {
      if (!mounted) return false;
      _showTopToast(
        ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not delete pin status',
        ),
      );
      return false;
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
        var coordinatePoints = pdfVerts != null
            ? _viewportPointsFromPdfVertices(pdfVerts)
            : _pointsFromCoordinates(plot['coordinates']);
        final rawPins = plot['pins'];
        // Some backends omit plot coordinates on read but still return pins.
        // When that happens, rebuild an approximate rectangle from the pins so
        // the blue selection area appears again around the saved pins.
        if (pdfVerts == null &&
            (coordinatePoints.length < 2) &&
            rawPins is List &&
            rawPins.isNotEmpty) {
          final pinPoints = <Offset>[];
          for (final pinRaw in rawPins) {
            if (pinRaw is! Map) continue;
            final p = Map<String, dynamic>.from(pinRaw);
            final x = _toDouble(p['x_coordinate']);
            final y = _toDouble(p['y_coordinate']);
            if (x == null || y == null) continue;
            pinPoints.add(_scenePointFromApiCoordinates(x, y));
          }
          if (pinPoints.length >= 2) {
            coordinatePoints = pinPoints;
          }
        }
        if (pdfVerts == null && coordinatePoints.length < 2) continue;
        final rect = coordinatePoints.length >= 2
            ? _rectFromCoordinatePoints(coordinatePoints)
            : (pdfVerts != null ? Rect.zero : null);
        if (rect == null && pdfVerts == null) continue;
        final shapeLines = coordinatePoints.length >= 3
            ? _linesFromCoordinatePoints(coordinatePoints)
            : const <_CanvasLine>[];
        final serverPlotId = readApiIntFromMap(
          Map<String, dynamic>.from(plot),
          const ['id', 'plot_id'],
        );
        final pins = <_CanvasPin>[];
        if (rawPins is List) {
          for (final pinRaw in rawPins) {
            if (pinRaw is! Map) continue;
            final p = Map<String, dynamic>.from(pinRaw);
            final x = _toDouble(p['x_coordinate']);
            final y = _toDouble(p['y_coordinate']);
            if (x == null || y == null) continue;
            final statusId = _readPinStatusId(p);
            final serverPinId = readApiIntFromMap(p, const ['id', 'pin_id']);
            final pageRaw = p['page'] ?? plot['page'];
            final page = pageRaw is int
                ? pageRaw
                : (pageRaw is num ? pageRaw.toInt() : 1);
            final portraitNorm = _apiPortraitNormFromRaw(x, y);
            final pinOffset = _canvasPinOffsetFromApi(x, y, page: page);
            final pinContentNorm = _usePdfViewport
                ? _normalizeScenePoint(pinOffset)
                : portraitNorm;
            final engine = _pdfEngine;
            final pdfPoint =
                engine?.annotationFromApiPercent(
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
            final compositeItemId = readApiIntFromMap(p, const [
              'item',
              'composite_item',
              'composite_item_id',
            ]) ??
                _readNestedId(p['item']) ??
                _readNestedId(p['composite_item']);
            var abbreviation = '';
            for (final key in const [
              'abbreviation',
              'short_code',
              'code',
            ]) {
              final raw = p[key];
              if (raw == null) continue;
              final text = raw.toString().trim();
              if (text.isNotEmpty) {
                abbreviation = text;
                break;
              }
            }
            abbreviation =
                abbreviation.isNotEmpty
                ? abbreviation
                : (_readNestedAbbreviation(
                      p['item'],
                    ) ??
                    _readNestedAbbreviation(p['composite_item']) ??
                    '');
            final productName = _readPinProductName(p);
            final formName = _readPinFormName(p);
            final formId = _readPinFormId(p);
            final attachmentNames = _readPinAttachments(p);
            final description = _readStringFromPinMap(
              p,
              const ['description', 'remarks', 'notes'],
            );
            final statusName =
                _readPinStatusName(p) ?? _statusNameById(statusId);
            final blockName = _readPinBlockName(p, _blockController.text.trim());
            final levelName = _readPinLevelName(p, _levelController.text.trim());
            final zoneName = _readPinPlotName(p, name);
            final variation = _readPinVariation(p);
            final droppedAt = _readPinDroppedAt(p) ?? DateTime.now();
            pins.add(
              _CanvasPin(
                offset: pinOffset,
                contentNormX: pinContentNorm.dx,
                contentNormY: pinContentNorm.dy,
                pdfPoint: pdfPoint,
                productName: productName,
                abbreviation: abbreviation,
                status: statusName,
                statusId: statusId,
                groupId:
                    (p['group'] is int
                        ? p['group'] as int
                        : int.tryParse('${p['group'] ?? ''}')) ??
                    _readNestedId(p['group']),
                compositeItemId: compositeItemId,
                quantity:
                    (p['quantity'] is int
                        ? p['quantity'] as int
                        : int.tryParse('${p['quantity'] ?? ''}')) ??
                    1,
                blockName: blockName,
                levelName: levelName,
                zoneName: zoneName,
                variation: variation,
                droppedAt: droppedAt,
                description: description,
                formName: formName,
                formId: formId,
                attachmentNames: attachmentNames,
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
          locked: shapeLines.length < 3,
          apiCoordinatesRaw: plot['coordinates'],
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
      unawaited(_hydratePinAbbreviationsForLoadedPlots());
      unawaited(_restoreGroupProductSelectionFromLoadedPins());
    } catch (_) {
      // keep UI editable even if preload fails
    }
  }

  Future<void> _restoreGroupProductSelectionFromLoadedPins() async {
    _CanvasPin? latest;
    for (var r = _regions.length - 1; r >= 0 && latest == null; r--) {
      final pins = _regions[r].pins;
      for (var p = pins.length - 1; p >= 0; p--) {
        final pin = pins[p];
        if (pin.groupId != null || pin.compositeItemId != null) {
          latest = pin;
          break;
        }
      }
    }
    final pin = latest;
    if (pin == null) return;

    final restoredBlock = pin.blockName.trim();
    if (_blockController.text.trim().isEmpty && restoredBlock.isNotEmpty) {
      _blockController.text = restoredBlock;
    }

    final groupId = pin.groupId;
    if (groupId != null) {
      if (_selectedGroupId != groupId) {
        setState(() => _selectedGroupId = groupId);
      }
      for (final g in _groupOptions) {
        if (g.id == groupId) {
          _groupController.text = g.name;
          break;
        }
      }
      await _loadCompositeItemsForGroup(groupId);
      if (!mounted) return;
    }

    final itemId = pin.compositeItemId;
    if (itemId == null) return;
    CompositeItemOption? selected;
    for (final item in _productOptions) {
      if (item.id == itemId) {
        selected = item;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _selectedCompositeItemId = itemId;
      if (selected != null) {
        _productController.text = selected.name;
      } else if (_productController.text.trim().isEmpty &&
          pin.productName.trim().isNotEmpty) {
        _productController.text = pin.productName.trim();
      }
    });
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
    return verts
        .map(engine.pdfToScreen)
        .whereType<Offset>()
        .toList(growable: false);
  }

  void _attachPdfPlotGeometry(
    _PlotRegion region,
    List<PdfAnnotationPoint> verts,
  ) {
    region.pdfVertices = verts;
    if (verts.length >= 2) {
      region.pdfAnchorA = verts.first;
      region.pdfAnchorB = verts.last;
    }
  }

  List<List<double>> _plotCoordinatesPayloadForApi(_PlotRegion region) {
    final verts = region.pdfVertices;
    if (verts != null && verts.isNotEmpty) {
      return verts
          .map((p) {
            final w = p.pageWidth > 0 ? p.pageWidth : 1.0;
            final h = p.pageHeight > 0 ? p.pageHeight : 1.0;
            return <double>[
              _plotCoordinateApiPercent(p.pdfX / w),
              _plotCoordinateApiPercent(p.pdfY / h),
            ];
          })
          .toList(growable: false);
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
          return <double>[
            _plotCoordinateApiPercent(landscapeNorm.dx),
            _plotCoordinateApiPercent(landscapeNorm.dy),
          ];
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
      points.add(_scenePointFromApiCoordinates(x, y));
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

  List<Map<String, dynamic>> _buildLevelPlotsPayload() {
    final plotsPayload = <Map<String, dynamic>>[];
    for (var i = 0; i < _regions.length; i++) {
      final region = _regions[i];
      if (!_plotRegionIsNamed(region)) continue;
      final pins = <Map<String, dynamic>>[];
      for (var p = 0; p < region.pins.length; p++) {
        final pin = region.pins[p];
        final engine = _pdfEngine;
        final pdfPoint =
            pin.pdfPoint ??
            (engine != null ? engine.viewportToAnnotation(pin.offset) : null);
        final apiCoords = pdfPoint != null
            ? PdfCoordinateCodec.annotationToApi(pdfPoint)
            : <String, dynamic>{
                'x_coordinate': (_normalizeScenePoint(pin.offset).dx * 100)
                    .round(),
                'y_coordinate': (_normalizeScenePoint(pin.offset).dy * 100)
                    .round(),
              };
        pins.add(<String, dynamic>{
          if (pin.serverPinId != null) 'id': pin.serverPinId,
          if (pdfPoint != null) 'page': pdfPoint.page,
          ...apiCoords,
          'status': pin.statusId ?? _statusIdByName(pin.status),
          'group': pin.groupId,
          if (pin.compositeItemId != null) 'item': pin.compositeItemId,
          if (pin.compositeItemId != null)
            'composite_item': pin.compositeItemId,
          if (pin.productName.trim().isNotEmpty) ...{
            'item_name': pin.productName.trim(),
            'product_name': pin.productName.trim(),
          },
          if (pin.blockName.trim().isNotEmpty)
            'block_name': pin.blockName.trim(),
          if (pin.levelName.trim().isNotEmpty)
            'level_name': pin.levelName.trim(),
          if (pin.zoneName.trim().isNotEmpty) 'plot_name': pin.zoneName.trim(),
          if (pin.formId != null) 'form_id': pin.formId,
          if (pin.formName.trim().isNotEmpty) 'form_name': pin.formName.trim(),
          'quantity': pin.quantity < 1 ? 1 : pin.quantity,
          if (pin.variation.trim().isNotEmpty)
            'variation': pin.variation.toLowerCase() == 'yes',
          'description': pin.description.trim(),
          'dropped_at': pin.droppedAt.toUtc().toIso8601String(),
          'attachments': [
            for (final name in pin.attachmentNames)
              <String, dynamic>{'name': name},
          ],
        });
      }
      final normalizedCoordinates = _plotCoordinatesPayloadForApi(region);
      final deletedPinIds = region.pendingDeletedPinIds.toList()..sort();
      final plotEntry = <String, dynamic>{
        if (region.serverPlotId != null) 'id': region.serverPlotId,
        'name': region.name!.trim(),
        'page': 1,
        'coordinates': normalizedCoordinates,
        'pins': pins,
      };
      if (deletedPinIds.isNotEmpty) {
        plotEntry['deleted_pin_ids'] = deletedPinIds;
      }
      plotsPayload.add(plotEntry);
    }
    return plotsPayload;
  }

  int _plotPageFromApiRaw(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 1;
  }

  /// Server expects existing plot ids with null/empty geometry — not top-level `plots: null`.
  Future<List<Map<String, dynamic>>> _fetchServerClearPlotsPayload({
    required String projectId,
    required String levelId,
  }) async {
    final api = ref.read(quoteProjectApiClientProvider);
    final levels = await api.fetchProjectLevels(projectId: projectId);
    ProjectLevelItem? level;
    for (final item in levels) {
      if (item.id.trim() == levelId) {
        level = item;
        break;
      }
    }
    final rawPlots = level?.plots ?? const <Map<String, dynamic>>[];
    if (rawPlots.isEmpty) return const <Map<String, dynamic>>[];

    return [
      for (final plot in rawPlots)
        <String, dynamic>{
          if (plot['id'] != null) 'id': plot['id'],
          'name': (plot['name'] ?? 'Plot').toString().trim().isEmpty
              ? 'Plot'
              : (plot['name'] ?? 'Plot').toString().trim(),
          'page': _plotPageFromApiRaw(plot['page']),
          'coordinates': null,
          'pins': null,
        },
    ];
  }

  Future<void> _submitLevelPlots({
    bool clearAllOnServer = false,
    bool popOnSuccess = true,
  }) async {
    if (_isSubmitting) return;
    final projectId = (_projectId ?? '').trim();
    final levelId = (_levelId ?? '').trim();
    if (projectId.isEmpty || levelId.isEmpty) {
      _showTopToast('Missing project or level id for submit');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final built = _buildLevelPlotsPayload();
      if (!clearAllOnServer && built.isEmpty) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showTopToast('Add a named plot area before saving pins.');
        return;
      }
      final bool clearedAll = clearAllOnServer;
      final List<Map<String, dynamic>> plotsForApi = clearedAll
          ? await _fetchServerClearPlotsPayload(
              projectId: projectId,
              levelId: levelId,
            )
          : built;
      final payload = <String, dynamic>{'plots': plotsForApi};
      debugPrint(
        '[DrawingCanvas] updateLevelPlots payload:\n'
        '${const JsonEncoder.withIndent('  ').convert(payload)}',
      );
      final api = ref.read(quoteProjectApiClientProvider);
      final responseBody = await api.updateLevelPlots(
        projectId: projectId,
        levelId: levelId,
        plots: plotsForApi,
      );
      if (!mounted) return;
      if (popOnSuccess && context.canPop()) {
        context.pop(true);
      } else {
        if (clearedAll) {
          _clearAllCanvasMarkup();
        } else {
          _clearPendingDeletedPinIds();
          await _loadSavedLevelMarkup();
          _logLevelPlotsSyncResult(responseBody);
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

  Widget _buildCanvasOverlayLayer({required bool pinLayerInteractive}) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: _buildRegionPaintLayer()),
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

  Widget _buildCanvasStack() {
    final pinLayerInteractive =
        !_overlayDrawListenerActive && _selectedTool == _CanvasTool.share;
    final pdfCtrl = _pdfController;
    final overlays = _usePdfViewport && pdfCtrl != null
        ? ListenableBuilder(
            listenable: pdfCtrl,
            builder: (context, child) => _buildCanvasOverlayLayer(
              pinLayerInteractive: pinLayerInteractive,
            ),
          )
        : _buildCanvasOverlayLayer(pinLayerInteractive: pinLayerInteractive);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: _buildDrawingPreview()),
        Positioned.fill(child: overlays),
      ],
    );
  }

  /// Pins stay visible on every tool; share tool enables tap-to-open sheet.
  Widget _buildPinHitTargetsLayer({required bool interactive}) {
    final selectedRegion = _selectedPinRegionIndex;
    final selectedPin = _selectedPinIndex;
    return Stack(
      clipBehavior: Clip.hardEdge,
      fit: StackFit.expand,
      children: [
        for (var r = 0; r < _regions.length; r++)
          for (var i = 0; i < _regions[r].pins.length; i++)
            if (!(selectedRegion == r && selectedPin == i))
            Builder(
              builder: (context) {
                final pin = _regions[r].pins[i];
                final anchor = _pinAnchorScene(pin);
                final pinSize = _pinSizeForScreen(context);
                final pointerH = _pinPointerHeightForScreen(context);
                final abbr = _pinDisplayAbbreviation(pin);
                if (!_shouldPaintPinAt(
                  anchor,
                  pinSize: pinSize,
                  pointerH: pointerH,
                )) {
                  return const SizedBox.shrink();
                }
                final pinWidget = PinView(
                  number: i + 1,
                  abbreviation: abbr,
                  size: pinSize,
                  pointerHeight: pointerH,
                  selected: false,
                );
                return Positioned(
                  left: anchor.dx - pinSize / 2,
                  top: anchor.dy - pinSize - pointerH,
                  child: interactive
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              _openPinDetailSheet(regionIndex: r, pinIndex: i),
                          child: pinWidget,
                        )
                      : IgnorePointer(child: pinWidget),
                );
              },
            ),
        if (selectedRegion != null &&
            selectedPin != null &&
            selectedRegion >= 0 &&
            selectedRegion < _regions.length &&
            selectedPin >= 0 &&
            selectedPin < _regions[selectedRegion].pins.length)
          Builder(
            builder: (context) {
              final pin = _regions[selectedRegion].pins[selectedPin];
              final anchor = _pinAnchorScene(pin);
              final pinSize = _pinSizeForScreen(context);
              final pointerH = _pinPointerHeightForScreen(context);
              final abbr = _pinDisplayAbbreviation(pin);
              if (!_shouldPaintPinAt(
                anchor,
                pinSize: pinSize,
                pointerH: pointerH,
              )) {
                return const SizedBox.shrink();
              }
              final pinWidget = PinView(
                number: selectedPin + 1,
                abbreviation: abbr,
                size: pinSize,
                pointerHeight: pointerH,
                selected: true,
              );
              return Positioned(
                left: anchor.dx - pinSize / 2,
                top: anchor.dy - pinSize - pointerH,
                child: interactive
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openPinDetailSheet(
                          regionIndex: selectedRegion,
                          pinIndex: selectedPin,
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
                    style: AppFonts.bodySmall(color: _regionBorderColor(r))
                        .copyWith(
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
              _selectedPinRegionIndex = _pinPointerDownHit!.regionIndex;
              _selectedPinIndex = _pinPointerDownHit!.pinIndex;
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
        if (_selectedTool == _CanvasTool.line && _lineDraftPoints.isNotEmpty) {
          setState(() => _lineDraftCurrent = scene);
        }
      },
      onPointerUp: (PointerUpEvent e) {
        _cancelPinLongPressTimer();
        final hadPinSession = _pinPointerDownHit != null;
        final skipTapSheet =
            hadPinSession && (_pinLongPressArmed || _pinDraggingAfterLongPress);
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
        (p - pressScene).distance >= _regionDragThreshold &&
        pressIdx >= 0 &&
        pressIdx < _regions.length &&
        !_regions[pressIdx].locked) {
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
        moveIdx < _regions.length &&
        !_regions[moveIdx].locked) {
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
    unawaited(_finalizeAreaSelection());
  }

  void _handleLineToolTap(Offset scenePoint) {
    if (_selectedTool != _CanvasTool.line) return;
    final points = List<Offset>.from(_lineDraftPoints);
    if (points.isEmpty) {
      if (_pointInsideAnyNamedPlot(scenePoint)) {
        _showTopToast(_plotOverlapMessage);
        return;
      }
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
      final prepared = _plotRegionWithSyncedRect(region) ?? region;
      setState(() {
        _lineDraftPoints.clear();
        _lineDraftCurrent = null;
      });
      if (_plotOverlapsAnyExistingNamedPlot(prepared)) {
        _showTopToast(_plotOverlapMessage);
        return;
      }
      unawaited(_commitNewPlotRegion(prepared));
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
                if (DrawingCanvasFeatureFlags.showDeleteTool) ...[
                  const SizedBox(width: 14),
                  _actionCircle(
                    iconAsset: AppImageString.deleteIconPng,
                    isDelete: true,
                    onTap: _onDeleteSelection,
                  ),
                ],
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
            child: ClipRect(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF3F3F4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _observeViewportGeometry(constraints.biggest);
                    return Stack(
                      clipBehavior: Clip.hardEdge,
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
                            child: Text(
                              p.abbreviation.trim().isNotEmpty
                                  ? '${p.abbreviation.trim()} · ${p.name}'
                                  : p.name,
                            ),
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
    this.abbreviation,
    this.size = 32,
    this.pointerHeight = 9,
    this.selected = false,
  });

  final int number;
  final String? abbreviation;
  final double size;
  final double pointerHeight;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final abbr = abbreviation?.trim() ?? '';
    final topAbbr = abbr.isEmpty ? '' : abbr.toUpperCase();

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
                  color: const Color(0xFFEFFAF4),
                  border: Border.all(
                    color: selected ? const Color(0xFF7C3AED) : const Color(0xFF0EA56A),
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
                            color: const Color(0xFF0A8F5D),
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
                        color: const Color(0xFF0A8F5D),
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
                  painter: const _PinTrianglePainter(
                    fillColor: Color(0xFF0EA56A),
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

String _readStringFromPinMap(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(
    value.map((k, v) => MapEntry(k.toString(), v)),
  );
}

String _readPinProductName(Map<String, dynamic> p) {
  final direct = _readStringFromPinMap(
    p,
    const ['item_name', 'product_name', 'name', 'title'],
  );
  if (direct.isNotEmpty) return direct;
  for (final key in const ['item', 'composite_item']) {
    final nested = _asStringKeyedMap(p[key]);
    if (nested == null) continue;
    final name = _readStringFromPinMap(
      nested,
      const ['item_name', 'name', 'title', 'product_name'],
    );
    if (name.isNotEmpty) return name;
  }
  return '';
}

String _readPinBlockName(Map<String, dynamic> p, String fallback) {
  final fromPin = _readStringFromPinMap(p, const ['block_name', 'block']);
  return fromPin.isNotEmpty ? fromPin : fallback;
}

String _readPinLevelName(Map<String, dynamic> p, String fallback) {
  final fromPin = _readStringFromPinMap(
    p,
    const ['level_name', 'level', 'level_label'],
  );
  return fromPin.isNotEmpty ? fromPin : fallback;
}

String _readPinPlotName(Map<String, dynamic> p, String plotFallback) {
  final fromPin = _readStringFromPinMap(
    p,
    const ['plot_name', 'zone', 'zone_name', 'plot'],
  );
  return fromPin.isNotEmpty ? fromPin : plotFallback;
}

int? _readPinStatusId(Map<String, dynamic> p) {
  final raw = p['status'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  final nested = _asStringKeyedMap(raw);
  if (nested != null) {
    final id = nested['id'] ?? nested['status_id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse('${id ?? ''}');
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
  return int.tryParse('${raw ?? ''}');
}

String? _readPinStatusName(Map<String, dynamic> p) {
  final nested = _asStringKeyedMap(p['status']);
  if (nested != null) {
    final name = _readStringFromPinMap(
      nested,
      const ['status_name', 'name', 'title', 'label'],
    );
    if (name.isNotEmpty) return name;
  }
  final direct = _readStringFromPinMap(
    p,
    const ['status_name', 'status_label'],
  );
  return direct.isEmpty ? null : direct;
}

String _readPinVariation(Map<String, dynamic> p) {
  final raw = p['variation'];
  if (raw is bool) return raw ? 'Yes' : 'No';
  if (raw is num) return raw != 0 ? 'Yes' : 'No';
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'yes' ||
        normalized == 'true' ||
        normalized == '1' ||
        normalized == 'y') {
      return 'Yes';
    }
    if (normalized == 'no' ||
        normalized == 'false' ||
        normalized == '0' ||
        normalized == 'n') {
      return 'No';
    }
  }
  return 'No';
}

DateTime? _readPinDroppedAt(Map<String, dynamic> p) {
  for (final key in const [
    'dropped_at',
    'created_at',
    'droppedAt',
    'createdAt',
  ]) {
    final raw = p[key];
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();
    }
  }
  return null;
}

int? _readNestedId(dynamic value) {
  if (value is Map) {
    final map = Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
    final idRaw = map['id'] ?? map['item'] ?? map['composite_item_id'];
    if (idRaw is int) return idRaw;
    if (idRaw is num) return idRaw.toInt();
    return int.tryParse('${idRaw ?? ''}');
  }
  return null;
}

String? _readNestedAbbreviation(dynamic value) {
  if (value is! Map) return null;
  final map = Map<String, dynamic>.from(
    value.map((k, v) => MapEntry(k.toString(), v)),
  );
  for (final key in const ['abbreviation', 'short_code', 'code']) {
    final raw = map[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String _readPinFormName(Map<String, dynamic> map) {
  for (final key in const [
    'form_name',
    'form_title',
    'linked_form_name',
  ]) {
    final raw = map[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  for (final key in const ['form', 'form_id', 'linked_form', 'job_form']) {
    final nested = _asStringKeyedMap(map[key]);
    if (nested == null) continue;
    final name = _readStringFromPinMap(
      nested,
      const ['name', 'title', 'form_name', 'label'],
    );
    if (name.isNotEmpty) return name;
  }
  return '';
}

int? _readPinFormId(Map<String, dynamic> map) {
  for (final key in const ['form_id', 'form', 'linked_form', 'job_form']) {
    final raw = map[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final nested = _asStringKeyedMap(raw);
    if (nested != null) {
      for (final idKey in const [
        'id',
        'form_id',
        'job_form_id',
        'project_form_id',
      ]) {
        final idRaw = nested[idKey];
        if (idRaw is int) return idRaw;
        if (idRaw is num) return idRaw.toInt();
        final parsed = int.tryParse('${idRaw ?? ''}');
        if (parsed != null) return parsed;
      }
    }
  }
  final direct = map['form_id'];
  if (direct is int) return direct;
  if (direct is num) return direct.toInt();
  return int.tryParse('${direct ?? ''}');
}

List<String> _readPinAttachments(Map<String, dynamic> map) {
  final raw = map['attachments'] ?? map['files'] ?? map['attachment'];
  if (raw is! List) return const <String>[];
  final out = <String>[];
  for (final entry in raw) {
    if (entry is Map) {
      final nested = Map<String, dynamic>.from(
        entry.map((k, v) => MapEntry(k.toString(), v)),
      );
      final name = nested['name']?.toString().trim() ??
          nested['file_name']?.toString().trim() ??
          nested['filename']?.toString().trim() ??
          nested['url']?.toString().trim() ??
          '';
      if (name.isNotEmpty) out.add(name);
    } else {
      final text = entry.toString().trim();
      if (text.isNotEmpty) out.add(text);
    }
  }
  return out;
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
    this.locked = false,
    Set<int>? pendingDeletedPinIds,
    this.apiCoordinatesRaw,
  }) : pendingDeletedPinIds = pendingDeletedPinIds ?? const <int>{};

  final Rect rect;
  final String? name;
  final List<_CanvasPin> pins;
  final List<_CanvasLine>? lines;
  final int? serverPlotId;

  /// Server pin ids removed locally; sent on next plot PUT as `deleted_pin_ids`.
  final Set<int> pendingDeletedPinIds;

  /// Raw `coordinates` from GET — used to re-layout after viewport is ready.
  final dynamic apiCoordinatesRaw;

  /// Box plots from the select-area tool cannot be dragged.
  final bool locked;

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
    bool? locked,
    Set<int>? pendingDeletedPinIds,
    dynamic apiCoordinatesRaw,
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
      locked: locked ?? this.locked,
      pendingDeletedPinIds: pendingDeletedPinIds ?? this.pendingDeletedPinIds,
      apiCoordinatesRaw: apiCoordinatesRaw ?? this.apiCoordinatesRaw,
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
    this.abbreviation = '',
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
    this.formName = '',
    this.formId,
    this.attachmentNames = const <String>[],
    this.serverPinId,
    this.contentNormX,
    this.contentNormY,
  });

  final Offset offset;

  /// Portrait-normalized position (0–1) inside the letterboxed image — for reload.
  final double? contentNormX;
  final double? contentNormY;

  /// True PDF user-space position; source of truth on PDF (not screen pixels).
  final PdfAnnotationPoint? pdfPoint;

  final String productName;
  final String abbreviation;
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
  final String formName;
  final int? formId;
  final List<String> attachmentNames;
  final int? serverPinId;

  _CanvasPin copyWith({
    Offset? offset,
    PdfAnnotationPoint? pdfPoint,
    String? productName,
    String? abbreviation,
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
    String? formName,
    int? formId,
    List<String>? attachmentNames,
    int? serverPinId,
    double? contentNormX,
    double? contentNormY,
  }) {
    return _CanvasPin(
      offset: offset ?? this.offset,
      contentNormX: contentNormX ?? this.contentNormX,
      contentNormY: contentNormY ?? this.contentNormY,
      pdfPoint: pdfPoint ?? this.pdfPoint,
      productName: productName ?? this.productName,
      abbreviation: abbreviation ?? this.abbreviation,
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
      formName: formName ?? this.formName,
      formId: formId ?? this.formId,
      attachmentNames: attachmentNames ?? this.attachmentNames,
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
    required this.onDeletePinStatus,
    this.levelId,
    this.levelLabel,
  });

  final int pinNumber;
  final _CanvasPin pin;
  final List<PinStatusItem> pinStatuses;
  final Future<PinStatusItem?> Function() onCreatePinStatus;
  final Future<PinStatusItem?> Function(PinStatusItem) onEditPinStatus;
  final Future<bool> Function(PinStatusItem) onDeletePinStatus;
  final String? levelId;
  final String? levelLabel;

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
  late List<String> _attachmentNames;
  int? _linkedFormId;
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

  void _rebuildStatusOptions() {
    _statusOptions = _pinStatusCatalog
        .where((e) => e.isActive)
        .map((e) => e.statusName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (_statusOptions.isEmpty) {
      _statusOptions = List<String>.from(_fallbackStatuses);
    }
  }

  @override
  void initState() {
    super.initState();
    _pinStatusCatalog = widget.pinStatuses
        .where((e) => e.isActive)
        .toList(growable: true);
    _productController = TextEditingController(text: widget.pin.productName);
    _descriptionController = TextEditingController(
      text: widget.pin.description,
    );
    _qtyController = TextEditingController(text: '${widget.pin.quantity}');
    _blockController = TextEditingController(text: widget.pin.blockName);
    _levelController = TextEditingController(text: widget.pin.levelName);
    _zoneController = TextEditingController(text: widget.pin.zoneName);
    _rebuildStatusOptions();
    _status = _statusOptions.contains(widget.pin.status)
        ? widget.pin.status
        : _statusOptions.first;
    _variation = _variationOptions.contains(widget.pin.variation)
        ? widget.pin.variation
        : _variationOptions.first;
    _attachmentNames = List<String>.from(widget.pin.attachmentNames);
    _linkedFormId = widget.pin.formId;
  }

  @override
  void didUpdateWidget(covariant _PinDetailBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinStatuses != oldWidget.pinStatuses) {
      _pinStatusCatalog = widget.pinStatuses
          .where((e) => e.isActive)
          .toList(growable: true);
      _rebuildStatusOptions();
      if (!_statusOptions.contains(_status)) {
        _status = _statusOptions.isNotEmpty
            ? _statusOptions.first
            : widget.pin.status;
      }
    }
  }

  @override
  void dispose() {
    scheduleDisposeTextControllers([
      _productController,
      _descriptionController,
      _qtyController,
      _blockController,
      _levelController,
      _zoneController,
    ]);
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
    _attachmentNames = List<String>.from(pin.attachmentNames);
    _linkedFormId = pin.formId;
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'doc',
        'docx',
      ],
    );
    if (!mounted || result == null) return;
    setState(() {
      for (final file in result.files) {
        final name = file.name.trim();
        if (name.isEmpty) continue;
        if (!_attachmentNames.contains(name)) {
          _attachmentNames.add(name);
        }
      }
    });
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

  /// Status label color on light UI (dropdown / field): prefer readable
  /// `text_colour`, else the status `bg_colour` so the name itself is colored.
  Color _statusLabelColor(PinStatusItem? item) {
    final accent =
        parseHexColor(item?.bgColour ?? '') ?? const Color(0xFF6B7280);
    final textColour = parseHexColor(item?.textColour ?? '');
    if (textColour != null && textColour.computeLuminance() < 0.55) {
      return textColour;
    }
    return accent;
  }

  Color _statusTintBackground(PinStatusItem? item) {
    final accent = _statusLabelColor(item);
    return accent.withValues(alpha: 0.14);
  }

  Widget _viewStatusPill() {
    final item = _statusItemByNameLocal(_status);
    final labelColor = _statusLabelColor(item);
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _statusTintBackground(item),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: labelColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        _status,
        style: AppFonts.titleSmall(
          color: labelColor,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }

  void _closePinSheet<T>([T? result]) {
    if (!mounted) return;
    popOverlaySafely<T>(context, result);
  }

  Future<void> _handleCreateStatus() async {
    unfocusPrimary();
    final created = await widget.onCreatePinStatus();
    if (!mounted || created == null) return;
    setState(() {
      _pinStatusCatalog.add(created);
      _rebuildStatusOptions();
      _status = created.statusName;
    });
  }

  Future<void> _handleEditStatus() async {
    unfocusPrimary();
    final current = _statusItemByNameLocal(_status);
    if (current == null) return;
    final updated = await widget.onEditPinStatus(current);
    if (!mounted || updated == null) return;
    setState(() {
      final idx = _pinStatusCatalog.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        _pinStatusCatalog[idx] = updated;
      } else if (updated.isActive) {
        _pinStatusCatalog.add(updated);
      }
      _rebuildStatusOptions();
      _status = updated.statusName;
    });
  }

  Future<void> _handleDeleteStatus() async {
    unfocusPrimary();
    final current = _statusItemByNameLocal(_status);
    if (current == null) return;
    final deleted = await widget.onDeletePinStatus(current);
    if (!mounted || !deleted) return;
    setState(() {
      _pinStatusCatalog.removeWhere((e) => e.id == current.id);
      _rebuildStatusOptions();
      _status = _statusOptions.isNotEmpty
          ? _statusOptions.first
          : _fallbackStatuses.first;
    });
  }

  /// Dropdown row: status name in its status color (not only a dot).
  Widget _statusMenuRow(String name) {
    final item = _statusItemByNameLocal(name);
    final labelColor = _statusLabelColor(item);
    return Text(
      name,
      style: AppFonts.bodyMedium(
        color: labelColor,
      ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Closed field: colored status text on light tint.
  Widget _statusSelectedChip(String name) {
    final item = _statusItemByNameLocal(name);
    final labelColor = _statusLabelColor(item);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        style: AppFonts.bodyMedium(
          color: labelColor,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusDropdown() {
    if (_statusOptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          'No statuses — tap Add status',
          style: AppFonts.bodySmall(color: AppColors.muted),
        ),
      );
    }

    final value = _statusOptions.contains(_status)
        ? _status
        : _statusOptions.first;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      dropdownColor: AppColors.white,
      iconEnabledColor: AppColors.inkStrong,
      iconDisabledColor: AppColors.muted,
      borderRadius: BorderRadius.circular(12),
      style: AppFonts.bodyMedium(
        color: _statusLabelColor(_statusItemByNameLocal(value)),
      ).copyWith(fontWeight: FontWeight.w700),
      items: _statusOptions
          .map(
            (name) => DropdownMenuItem<String>(
              value: name,
              child: _statusMenuRow(name),
            ),
          )
          .toList(growable: false),
      selectedItemBuilder: (context) => _statusOptions
          .map((name) => _statusSelectedChip(name))
          .toList(growable: false),
      onChanged: (v) {
        unfocusPrimary();
        setState(() => _status = v ?? _status);
      },
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.textFieldFocusBorder),
        ),
      ),
    );
  }

  Widget _statusManageRow() {
    final canEdit = _statusItemByNameLocal(_status) != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton.icon(
            onPressed: _handleCreateStatus,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add status'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (canEdit) ...[
            TextButton.icon(
              onPressed: _handleEditStatus,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkStrong,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            TextButton.icon(
              onPressed: _handleDeleteStatus,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _sheetBg = AppColors.white;
  static const _sheetCard = AppColors.surfaceHigh;
  static const _sheetMuted = AppColors.muted;
  static const _sheetDivider = AppColors.borderLight;
  static const _sheetInk = AppColors.inkStrong;

  TextStyle get _sheetValueStyle => AppFonts.bodySmall(
        color: _sheetInk,
      ).copyWith(fontSize: 13, fontWeight: FontWeight.w600);

  TextStyle get _sheetLabelStyle => AppFonts.bodySmall(
        color: _sheetMuted,
      ).copyWith(fontSize: 13, fontWeight: FontWeight.w500);

  String _displayOrDash(String value) =>
      value.trim().isEmpty ? '—' : value.trim();

  String _levelDisplayLabel() {
    final id = (widget.levelId ?? '').trim();
    final label = (widget.levelLabel ?? '').trim();
    if (id.isNotEmpty) return '$id (1)';
    if (label.isNotEmpty) return label;
    final fromPin = widget.pin.levelName.trim();
    return fromPin.isEmpty ? '—' : fromPin;
  }

  String _coordPercent(_CanvasPin pin, {required bool x}) {
    final norm = x ? pin.contentNormX : pin.contentNormY;
    if (norm != null) return '${(norm * 100).toStringAsFixed(2)}%';
    final pt = pin.pdfPoint;
    if (pt != null) {
      final v = x ? pt.fractionX : pt.fractionY;
      return '${(v * 100).toStringAsFixed(2)}%';
    }
    return '—';
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: _sheetMuted),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: _sheetLabelStyle)),
              const SizedBox(width: 12),
              Flexible(child: trailing),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _sheetDivider),
      ],
    );
  }

  Widget _detailTextValue(String value, {TextAlign align = TextAlign.right}) {
    return Text(
      _displayOrDash(value),
      textAlign: align,
      style: _sheetValueStyle,
    );
  }

  Widget _linkedFormTrailing(
    String formName,
    int? formId, {
    bool alignStart = false,
  }) {
    final label = formName.trim();
    if (label.isEmpty && formId == null) {
      return _detailTextValue('No form linked');
    }
    final display = label.isNotEmpty
        ? label
        : (formId != null ? 'Form #$formId' : 'Linked form');
    return Align(
      alignment: alignStart ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.brandPrimaryContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 16,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                display,
                style: AppFonts.labelMedium(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _descriptionTrailing(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return _detailTextValue('—');
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          trimmed,
          textAlign: TextAlign.left,
          style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _attachmentsTrailing({required bool editing}) {
    if (_attachmentNames.isEmpty && !editing) {
      return _detailTextValue('No attachments');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_attachmentNames.isNotEmpty && !editing)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_attachmentNames.length} file${_attachmentNames.length == 1 ? '' : 's'} attached',
                style: AppFonts.labelSmall(color: const Color(0xFF0B6E99))
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (_attachmentNames.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              for (var i = 0; i < _attachmentNames.length; i++)
                InputChip(
                  label: Text(
                    _attachmentNames[i],
                    style: AppFonts.labelSmall(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  deleteIcon: editing
                      ? const Icon(Icons.close_rounded, size: 16)
                      : null,
                  onDeleted: editing
                      ? () => setState(() => _attachmentNames.removeAt(i))
                      : null,
                  backgroundColor: const Color(0xFFF3F3F4),
                  side: const BorderSide(color: Color(0xFFE3E3E5)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        if (editing) ...[
          if (_attachmentNames.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickAttachments,
            icon: const Icon(Icons.attach_file_rounded, size: 18),
            label: const Text('Add file'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              side: const BorderSide(color: Color(0xFFD9D9DC)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _coordinatesCard(_CanvasPin pin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _sheetCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _sheetDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'X COORDINATE',
                  style: _sheetCapsLabelStyle.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  _coordPercent(pin, x: true),
                  style: AppFonts.titleSmall(color: _sheetInk).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Y COORDINATE',
                  style: _sheetCapsLabelStyle.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  _coordPercent(pin, x: false),
                  style: AppFonts.titleSmall(color: _sheetInk).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewStatusBadge() {
    final item = _statusItemByNameLocal(_status);
    final labelColor = _statusLabelColor(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: labelColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timelapse, size: 14, color: labelColor),
          const SizedBox(width: 6),
          Text(
            _status,
            style: AppFonts.labelMedium(color: labelColor).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildViewModeChildren(_CanvasPin pin) {
    final productTitle = _productController.text.trim().isNotEmpty
        ? _productController.text.trim()
        : (pin.productName.trim().isNotEmpty
            ? pin.productName.trim()
            : 'Pin ${widget.pinNumber}');
    final qty = int.tryParse(_qtyController.text.trim()) ?? pin.quantity;
    final plotName = _zoneController.text.trim();
    final formName = widget.pin.formName.trim();
    final descriptionText = _descriptionController.text.trim();

    return [
      _sheetGrabHandle(),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location #${widget.pinNumber}',
                  style: AppFonts.titleMedium(
                    color: _sheetInk,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  productTitle,
                  style: AppFonts.bodyMedium(
                    color: _sheetMuted,
                  ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              side: const BorderSide(color: Color(0xFFD9D9DC)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _closePinSheet(),
            icon: const Icon(Icons.close_rounded, size: 22),
            color: _sheetMuted,
            splashRadius: 22,
          ),
        ],
      ),
      const SizedBox(height: 8),
      _detailRow(
        icon: Icons.inventory_2_outlined,
        label: 'Product Name',
        trailing: _detailTextValue(productTitle),
      ),
      _detailRow(
        icon: Icons.add_box_outlined,
        label: 'Quantity',
        trailing: _detailTextValue('$qty'),
      ),
      _detailRow(
        icon: Icons.timelapse,
        label: 'Status',
        trailing: Align(
          alignment: Alignment.centerRight,
          child: _viewStatusBadge(),
        ),
      ),
      _detailRow(
        icon: Icons.location_on_outlined,
        label: 'Location',
        trailing: _detailTextValue('${widget.pinNumber}'),
      ),
      _detailRow(
        icon: Icons.layers_outlined,
        label: 'Plot',
        trailing: _detailTextValue(plotName),
      ),
      _detailRow(
        icon: Icons.grid_on_outlined,
        label: 'Level',
        trailing: _detailTextValue(_levelDisplayLabel()),
      ),
      _detailRow(
        icon: Icons.description_outlined,
        label: 'Description',
        trailing: _descriptionTrailing(descriptionText),
      ),
      _detailRow(
        icon: Icons.attach_file_rounded,
        label: 'Attachments',
        trailing: _attachmentsTrailing(editing: false),
      ),
      _detailRow(
        icon: Icons.assignment_outlined,
        label: 'Linked Form',
        trailing: _linkedFormTrailing(formName, _linkedFormId),
      ),
      _detailRow(
        icon: Icons.layers_outlined,
        label: 'Variation',
        trailing: Align(
          alignment: Alignment.centerRight,
          child: CupertinoSwitch(
            value: _variation == 'Yes',
            onChanged: null,
            activeTrackColor: const Color(0xFF3B82F6),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'LOCATION',
        style: _sheetCapsLabelStyle,
      ),
      const SizedBox(height: 10),
      _coordinatesCard(pin),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () =>
              _closePinSheet(const _PinSheetResult(removePin: true)),
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
          label: Text(
            'Delete Pin',
            style: AppFonts.titleMedium(
              color: const Color(0xFFEF4444),
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            backgroundColor: AppColors.white,
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
      fillColor: AppColors.white,
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
            onPressed: () => _closePinSheet(),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetFieldLabel('Status'),
                const SizedBox(height: 6),
                _statusDropdown(),
              ],
            ),
          ),
        ],
      ),
      _statusManageRow(),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Plot'),
                const SizedBox(height: 6),
                _editTextField(controller: _zoneController, hint: 'Plot name'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetFieldLabel('Location'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    '${widget.pinNumber}',
                    style: AppFonts.bodyMedium(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
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
                _sheetFieldLabel('Linked Form'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: _linkedFormTrailing(
                    pin.formName,
                    _linkedFormId,
                    alignStart: true,
                  ),
                ),
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
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
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
      const SizedBox(height: 18),
      _sheetFieldLabel('Attachments'),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: _attachmentsTrailing(editing: true),
      ),
      const SizedBox(height: 20),
      Text('LOCATION', style: _sheetCapsLabelStyle),
      const SizedBox(height: 10),
      _coordinatesCard(pin),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF070A0E),
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.disabledButton,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            final qty =
                int.tryParse(_qtyController.text.trim()) ?? pin.quantity;
            _closePinSheet(
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
                  formName: pin.formName,
                  formId: _linkedFormId,
                  attachmentNames: List<String>.from(_attachmentNames),
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
            backgroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.border),
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
    final lightTheme = Theme.of(context).copyWith(
      brightness: Brightness.light,
      canvasColor: AppColors.white,
      scaffoldBackgroundColor: AppColors.white,
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.light,
        surface: AppColors.white,
        onSurface: AppColors.inkStrong,
      ),
    );

    return Theme(
      data: lightTheme,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) unfocusPrimary();
        },
        child: Material(
          color: AppColors.white,
          surfaceTintColor: Colors.transparent,
          child: SafeArea(
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
                  return ColoredBox(
                    color: AppColors.white,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      children: _isEditing
                          ? _buildEditModeChildren(pin)
                          : _buildViewModeChildren(pin),
                    ),
                  );
                },
              ),
            ),
          ),
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
    scheduleDisposeTextControllers([_controller]);
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
