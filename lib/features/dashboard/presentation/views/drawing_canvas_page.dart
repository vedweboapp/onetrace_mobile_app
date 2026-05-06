import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

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
  bool _isLoadingGroups = false;
  bool _isLoadingCompositeItems = false;
  static const List<Color> _regionPalette = <Color>[
    Color(0x331E7DD8), // blue
    Color(0x33F97316), // orange
    Color(0x33A855F7), // purple
    Color(0x3322C55E), // green
    Color(0x33EC4899), // pink
    Color(0x33F59E0B), // amber
  ];
  PdfControllerPinch? _pdfController;
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

  bool get _canPanCanvas =>
      _selectedTool == _CanvasTool.pin ||
      (_selectedTool == _CanvasTool.selectArea &&
          !_isDrawingSelectionGesture &&
          !_isDraggingPinGesture);

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
    } else {
      _activeFilePath = null;
    }
    _projectId = (widget.projectId ?? '').trim();
    _levelId = (widget.levelId ?? '').trim();
    _loadPinStatuses();
    _loadGroupAndCompositeOptions();
    _loadSavedLevelMarkup();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureDrawingSourceReady());
    });
  }

  void _initPdfControllerForActivePath() {
    final path = (_activeFilePath ?? '').trim();
    if (path.isEmpty || !File(path).existsSync()) return;
    if (!path.toLowerCase().endsWith('.pdf')) return;
    _pdfController?.dispose();
    _pdfController = PdfControllerPinch(document: PdfDocument.openFile(path));
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
      _pdfController?.dispose();
      _pdfController = null;
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
    _pdfController?.dispose();
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
        width: 250,
        height: 150,
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
        width: 250,
        height: 150,
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
        width: 250,
        height: 150,
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
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDADADD)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: IgnorePointer(
            // Keep zoom source single (InteractiveViewer) so PDF and
            // selected regions scale together.
            ignoring: true,
            child: PdfViewPinch(
              controller: _pdfController!,
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
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            'Could not open image',
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
        ),
      );
    }

    return Container(
      width: 280,
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

  Future<void> _pickMultiplePdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final pickedPaths = result.files
        .map((file) => (file.path ?? '').trim())
        .where((path) => path.isNotEmpty)
        .toList();
    if (pickedPaths.isEmpty) return;

    _persistActiveRegionsToCache();

    final keySeen = <String>{};
    final merged = <String>[];
    for (final p in _uploadedPdfPaths) {
      final k = _pdfStorageKey(p);
      if (keySeen.add(k)) merged.add(k);
    }
    for (final p in pickedPaths) {
      final k = _pdfStorageKey(p);
      if (keySeen.add(k)) merged.add(k);
    }
    final selectedPath = _pdfStorageKey(pickedPaths.first);

    _pdfController?.dispose();
    final nextController = PdfControllerPinch(
      document: PdfDocument.openFile(selectedPath),
    );

    final restored = _regionsByPdfPath[selectedPath];
    final restoredLines = _linesByPdfPath[selectedPath];

    setState(() {
      _uploadedPdfPaths
        ..clear()
        ..addAll(merged);
      _activeFilePath = selectedPath;
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
  }

  void _switchActivePdf(String path) {
    final trimmed = _pdfStorageKey(path);
    if (trimmed.isEmpty || trimmed == _activeFilePath) return;
    _persistActiveRegionsToCache();
    _pdfController?.dispose();
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
  }

  Offset _toScene(Offset viewportPoint) {
    return _viewerTransform.toScene(viewportPoint);
  }

  Offset _globalPositionToScene(Offset global) {
    final ctx = _viewportCanvasKey.currentContext;
    if (ctx == null) return Offset.zero;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return Offset.zero;
    final local = box.globalToLocal(global);
    return _viewerTransform.toScene(local);
  }

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

  Offset _canvasPinOffsetFromApi(double x, double y, Rect plotRect) {
    final pixelCandidate = Offset(x, y);
    // Large values are canvas pixel coords from this screen; skip %/fraction remap.
    if (x.abs() > 105 || y.abs() > 105) {
      return pixelCandidate;
    }
    if (plotRect.inflate(96).contains(pixelCandidate)) {
      return pixelCandidate;
    }
    final nx = (x > 1 ? x / 100.0 : x).clamp(0.0, 1.0);
    final ny = (y > 1 ? y / 100.0 : y).clamp(0.0, 1.0);
    return Offset(
      plotRect.left + nx * plotRect.width,
      plotRect.top + ny * plotRect.height,
    );
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
    setState(() {
      final pins = List<_CanvasPin>.from(region.pins);
      pins[hit.pinIndex] = pins[hit.pinIndex].copyWith(offset: clamped);
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
    });
  }

  void _showTopToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    final topInset =
        MediaQuery.of(context).viewPadding.top + kToolbarHeight + 8;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(12, topInset, 12, 0),
        ),
      );
  }

  Future<void> _onDeleteSelection() async {
    final hasSelections = _regions.isNotEmpty;
    if (!hasSelections) {
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
            'Are you sure you want to remove all selected areas and pins from this drawing?',
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
    setState(() {
      _selectedTool = null;
      _isSelectAllEnabled = false;
      _regions.clear();
      _activeRegionIndex = null;
      _draftStart = null;
      _draftCurrent = null;
      _movingRegionIndex = null;
      _regionMoveAnchorScene = null;
      _selectAreaPointerDown = false;
    });
    _persistActiveRegionsToCache();
    _showTopToast('All selections removed');
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

  Path _regionPath(_PlotRegion region) {
    final shapeLines = region.safeLines;
    if (shapeLines.length < 3) {
      return Path()..addRect(region.rect);
    }
    final path = Path()
      ..moveTo(shapeLines.first.start.dx, shapeLines.first.start.dy);
    for (final line in shapeLines) {
      path.lineTo(line.end.dx, line.end.dy);
    }
    path.close();
    return path;
  }

  bool _regionContainsPoint(_PlotRegion region, Offset point) {
    return _regionPath(region).contains(point);
  }

  String _shortPlotName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '';
    const maxChars = 4;
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}...';
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
    setState(() {
      _regions.add(
        _PlotRegion(
          rect: rect,
          name: null,
          pins: <_CanvasPin>[],
          lines: const <_CanvasLine>[],
        ),
      );
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
    final scenePoint = _toScene(details.localPosition);
    if (_selectedTool == _CanvasTool.line) {
      _handleLineToolTap(scenePoint);
      return;
    }
    if (_selectedTool == _CanvasTool.pin) {
      return;
    }
    final tappedPin = _findPinAtScenePoint(scenePoint);
    if (tappedPin != null) {
      if (_suppressPinTapSheetOnce) {
        _suppressPinTapSheetOnce = false;
      } else {
        _openPinDetailSheet(
          regionIndex: tappedPin.regionIndex,
          pinIndex: tappedPin.pinIndex,
        );
      }
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
      final nextPins = List<_CanvasPin>.from(region.pins)
        ..add(
          _CanvasPin(
            offset: p,
            productName: product,
            status: 'In Progress',
            statusId: _statusIdByName('In Progress'),
            groupId: selectedGroupId,
            compositeItemId: selectedCompositeItemId,
            quantity: 1,
            blockName: _blockController.text.trim(),
            levelName: _levelController.text.trim(),
            zoneName: (region.name ?? '').trim(),
            variation: 'No',
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
        final pinAnchor = pins[p].offset;
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
        final rect = _rectFromCoordinates(plot['coordinates']);
        if (rect == null) continue;
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
            pins.add(
              _CanvasPin(
                offset: _canvasPinOffsetFromApi(x, y, rect),
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
        loaded.add(
          _PlotRegion(
            rect: rect,
            name: name,
            pins: pins,
            lines: const <_CanvasLine>[],
            serverPlotId: serverPlotId,
          ),
        );
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
    } catch (_) {
      // keep UI editable even if preload fails
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  Rect? _rectFromCoordinates(dynamic rawCoordinates) {
    if (rawCoordinates is! List || rawCoordinates.length < 2) return null;
    final points = <Offset>[];
    for (final point in rawCoordinates) {
      if (point is! List || point.length < 2) continue;
      final x = _toDouble(point[0]);
      final y = _toDouble(point[1]);
      if (x == null || y == null) continue;
      points.add(Offset(x, y));
    }
    if (points.length < 2) return null;
    return Rect.fromPoints(points.first, points.last);
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
          pins.add(<String, dynamic>{
            if (pin.serverPinId != null) 'id': pin.serverPinId,
            'x_coordinate': pin.offset.dx.round(),
            'y_coordinate': pin.offset.dy.round(),
            'status': pin.statusId ?? _statusIdByName(pin.status),
            'group': pin.groupId,
            'item': pin.compositeItemId,
            'quantity': pin.quantity < 1 ? 1 : pin.quantity,
            if (pin.variation.trim().isNotEmpty)
              'variation': pin.variation.toLowerCase() == 'yes',
          });
        }
        plotsPayload.add(<String, dynamic>{
          if (region.serverPlotId != null) 'id': region.serverPlotId,
          'name': (region.name ?? '').trim().isEmpty
              ? 'Plot ${i + 1}'
              : region.name!.trim(),
          'coordinates': <List<int>>[
            <int>[region.rect.left.round(), region.rect.top.round()],
            <int>[region.rect.right.round(), region.rect.bottom.round()],
          ],
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
      if (context.canPop()) {
        context.pop(true);
      } else {
        await _loadSavedLevelMarkup();
        if (!mounted) return;
        _showTopToast('Selection and pins saved successfully');
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

  Widget _buildCanvasInteractionLayer() {
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
                  fillColor: _regionPalette[r % _regionPalette.length],
                  borderColor: r == _activeRegionIndex
                      ? const Color(0xFF1E7DD8)
                      : const Color(0xFF9CA3AF),
                  borderWidth: r == _activeRegionIndex ? 2 : 1.4,
                ),
              ),
            ),
          ),
        if (draftRect != null)
          Positioned.fromRect(
            rect: draftRect,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x221E7DD8),
                border: Border.all(color: const Color(0xFF1E7DD8), width: 2),
                borderRadius: BorderRadius.circular(4),
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
                  color: const Color(0xFF2563EB),
                  strokeWidth: 2.0,
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
                  color: const Color(0xFF2563EB),
                  strokeWidth: 2.0,
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
              rect: _regions[r].rect,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0F12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _shortPlotName(_regions[r].name).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppFonts.bodySmall(
                      color: AppColors.white,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < _regions[r].pins.length; i++)
            Positioned(
              left:
                  _regions[r].pins[i].offset.dx -
                  _pinSizeForScreen(context) / 2,
              top:
                  _regions[r].pins[i].offset.dy -
                  _pinSizeForScreen(context) -
                  _pinPointerHeightForScreen(context),
              child: PinView(
                number: i + 1,
                size: _pinSizeForScreen(context),
                pointerHeight: _pinPointerHeightForScreen(context),
              ),
            ),
        ],
      ],
    );
  }

  void _startSelectAreaFromScene(Offset p) {
    if (_selectedTool != _CanvasTool.selectArea) return;
    final moveIdx = _topRegionIndexContaining(p);
    if (moveIdx != null) {
      setState(() {
        _movingRegionIndex = moveIdx;
        _regionMoveAnchorScene = p;
        _activeRegionIndex = moveIdx;
        _draftStart = null;
        _draftCurrent = null;
      });
      return;
    }
    setState(() {
      _movingRegionIndex = null;
      _regionMoveAnchorScene = null;
      _draftStart = p;
      _draftCurrent = p;
    });
  }

  void _updateSelectAreaFromScene(Offset p) {
    if (_selectedTool != _CanvasTool.selectArea || !_selectAreaPointerDown) {
      return;
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
        final nextPins = region.pins
            .map((pin) => pin.copyWith(offset: pin.offset + delta))
            .toList();
        final nextLines = region.safeLines
            .map(
              (line) =>
                  _CanvasLine(start: line.start + delta, end: line.end + delta),
            )
            .toList();
        _regions[moveIdx] = region.copyWith(
          rect: nextRect,
          pins: nextPins,
          lines: nextLines,
        );
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
      setState(() {
        _regions.add(
          _PlotRegion(
            rect: rect,
            name: null,
            pins: <_CanvasPin>[],
            lines: polygonLines,
          ),
        );
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
    final current = _viewerTransform.value;
    final currentScale = current.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(0.5, 8.0);
    final ratio = nextScale / currentScale;
    _viewerTransform.value = current.multiplied(
      Matrix4.identity()..scale(ratio),
    );
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
          if (_selectedTool == _CanvasTool.selectArea)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // if (_isSelectAllEnabled)
                  if (_uploadedPdfPaths.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Each uploaded PDF keeps its own areas and pins — use the tabs above the canvas to switch.',
                        style: AppFonts.bodySmall(color: AppColors.muted),
                      ),
                    ),
                ],
              ),
            ),
          if (_selectedTool == _CanvasTool.line)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Line tool: tap multiple points to draw shape edges, then tap near the first point to close and create the plot area.',
                style: AppFonts.bodySmall(color: AppColors.muted),
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _viewerTransform,
                      minScale: 0.5,
                      maxScale: 8,
                      panEnabled: _canPanCanvas,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: SizedBox.expand(
                        child: Stack(
                          children: [
                            Center(child: _buildDrawingPreview()),
                            Positioned.fill(
                              child: _buildCanvasInteractionLayer(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    key: _viewportCanvasKey,
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
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
                        } else {
                          _suppressPinTapSheetOnce = false;
                          _pinLongPressArmed = false;
                          _pinDraggingAfterLongPress = false;
                          _cancelPinLongPressTimer();
                          _selectAreaPointerDown = false;
                          final downScene = _globalPositionToScene(e.position);
                          if (_selectedTool == _CanvasTool.location) {
                            _pinPointerDownHit = _findPinAtScenePoint(
                              downScene,
                            );
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
                      child: IgnorePointer(
                        // Let InteractiveViewer fully handle pinch/multi-touch.
                        ignoring: _activePointers > 1,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          // Select-area moves & pin drags use [Listener] only so PanGesture never
                          // wins the arena and cancels pointers (that was breaking pin/long-press drag).
                          onTapUp: _onCanvasTapUp,
                        ),
                      ),
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
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _pickMultiplePdfs,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F1013),
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: Text(
                              'Upload PDF',
                              style: AppFonts.titleSmall(
                                color: AppColors.white,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _blockController,
                          hintText: 'Block :',
                          fillColor: const Color(0xFFF2F2F3),
                          borderRadius: 12,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AppTextField(
                          controller: _levelController,
                          hintText: 'Level :',
                          fillColor: const Color(0xFFF2F2F3),
                          borderRadius: 12,
                        ),
                      ),
                    ],
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
                      hintText: _isLoadingGroups ? 'Loading groups...' : 'Group',
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
                    value: _productOptions.any(
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
                    onChanged: (_selectedGroupId == null || _isLoadingCompositeItems)
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
                                ? 'Loading composite items...'
                                : 'Composite Item'),
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
  });

  final Path path;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _RegionShapePainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

class _PlotRegion {
  const _PlotRegion({
    required this.rect,
    required this.name,
    required this.pins,
    this.lines,
    this.serverPlotId,
  });

  final Rect rect;
  final String? name;
  final List<_CanvasPin> pins;
  final List<_CanvasLine>? lines;
  final int? serverPlotId;
  List<_CanvasLine> get safeLines => lines ?? const <_CanvasLine>[];

  _PlotRegion copyWith({
    Rect? rect,
    String? name,
    List<_CanvasPin>? pins,
    List<_CanvasLine>? lines,
    int? serverPlotId,
  }) {
    return _PlotRegion(
      rect: rect ?? this.rect,
      name: name ?? this.name,
      pins: pins ?? this.pins,
      lines: lines ?? this.lines ?? const <_CanvasLine>[],
      serverPlotId: serverPlotId ?? this.serverPlotId,
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
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _variationOptions.contains(_variation)
                      ? _variation
                      : _variationOptions.first,
                  items: _variationOptions
                      .map(
                        (v) =>
                            DropdownMenuItem<String>(value: v, child: Text(v)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _variation = v ?? _variation),
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
