part of 'quote_project.dart';

class QuoteProjectPage extends ConsumerStatefulWidget {
  const QuoteProjectPage({
    super.key,
    this.initialBlockName,
    this.initialProjectId,
    this.initialOrganizationId,
    this.initialClientId,
    this.initialProjectDescription,
    this.initialStartDate,
    this.initialEndDate,
    this.initialPdfUrl,
    this.initialPdfName,
    this.initialProducts,
  });

  /// When set (e.g. opened from dashboard), loads that block and skips the new-block dialog.
  final String? initialBlockName;
  final String? initialProjectId;
  final int? initialOrganizationId;
  final int? initialClientId;
  final String? initialProjectDescription;
  final String? initialStartDate;
  final String? initialEndDate;
  final String? initialPdfUrl;
  final String? initialPdfName;
  final List<Map<String, dynamic>>? initialProducts;

  static const path = '/quote-project';
  static const name = 'quote-project';

  @override
  ConsumerState<QuoteProjectPage> createState() => _QuoteProjectPageState();
}

class _QuoteProjectPageState extends ConsumerState<QuoteProjectPage> {
  static const String _pdfLoadLogTag = '[QuoteProjectPDF]';
  bool _showSearchField = false;
  final TextEditingController _searchController = TextEditingController();

  final GlobalKey _canvasKey = GlobalKey();
  final ScrollController _carouselScroll = ScrollController();

  final List<_UploadedDoc> _documents = [];
  int _selectedIndex = 0;

  String? _blockName;
  bool _didBootstrap = false;

  PdfControllerPinch? _pdfController;
  final Map<String, PdfPageMetadataCache> _pdfMetadataByPath = {};

  PdfCoordinateEngine? get _pdfEngine {
    final ctrl = _pdfController;
    final doc = _selectedDoc;
    if (ctrl == null || doc == null || !doc.isPdf) return null;
    final meta = _pdfMetadataByPath[doc.identityKey];
    if (meta == null) return null;
    return PdfCoordinateEngine(controller: ctrl, metadata: meta);
  }

  final TransformationController _imageTransform = TransformationController();

  int _zoomPercent = 100;

  static const double _carouselCardSize = 72;
  static const double _carouselGap = 10;

  QuoteCanvasTool _canvasTool = QuoteCanvasTool.pan;

  /// Picked from bottom-bar selectors; persisted with the block quotation.
  String? _selectedGroup;
  String? _selectedProduct;

  /// Keyed by file path so marks stay tied to the file when the carousel changes.
  final Map<String, QuoteDocMarkup> _markupByPath = {};

  QuoteDocMarkup get _markupForCurrentDoc {
    final p = _selectedDoc?.identityKey;
    if (p == null) return QuoteDocMarkup();
    return _markupByPath.putIfAbsent(p, () => QuoteDocMarkup());
  }

  /// Pins are shown and can be placed only after GROUP + Place Pin (product) are chosen.
  bool get _pinContextReady {
    final g = (_selectedGroup ?? '').trim();
    final p = (_selectedProduct ?? '').trim();
    return g.isNotEmpty && p.isNotEmpty;
  }

  String? _sourceBlockName;
  String? _projectId;
  int? _organizationId;
  int? _clientId;
  String? _projectDescription;
  String? _startDate;
  String? _endDate;
  bool _didSeedInitialPdf = false;
  bool _isOpeningInitialPdf = false;
  bool _isSubmitting = false;

  void _onMarkupChanged() {
    setState(() {});
  }

  void _onPinPlacementRejected(QuotePinPlacementRejection reason) {
    if (!mounted) return;
    final msg = switch (reason) {
      QuotePinPlacementRejection.noAreaSelected =>
        'Please select an area with Box or Polygon before placing a pin.',
      QuotePinPlacementRejection.outsideSelectedArea =>
        'Please place the pin inside a highlighted area.',
      QuotePinPlacementRejection.missingGroupOrProduct =>
        'Select a group and a product under â€œPlace Pinâ€ before placing or viewing pins.',
      QuotePinPlacementRejection.overlapsExistingPin =>
        'A pin already exists here. Move it or drop this pin at a different spot.',
    };
    context.showTopSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _openPinDetail(int index) {
    final pins = _markupForCurrentDoc.pins;
    if (index < 0 || index >= pins.length) return;
    final pin = pins[index];
    unawaited(
      showPinDetailSheet(
        context: context,
        pinIndex: index,
        pin: pin,
        onRemoved: () {
          if (!mounted) return;
          setState(() {
            _markupForCurrentDoc.pins.removeAt(index);
          });
          _onMarkupChanged();
          unawaited(_persistBlockQuotation());
        },
        onPinChanged: (updatedPin) {
          if (!mounted) return;
          setState(() {
            if (index < _markupForCurrentDoc.pins.length) {
              _markupForCurrentDoc.pins[index] = updatedPin;
            }
          });
          _logUpdatedPinPayload(updatedPin: updatedPin, pinIndex: index);
          _onMarkupChanged();
          unawaited(_persistBlockQuotation());
        },
      ),
    );
  }

  void _logUpdatedPinPayload({
    required PinEntry updatedPin,
    required int pinIndex,
  }) {
    final payload = <String, dynamic>{
      'pin_index': pinIndex,
      'doc_identity': _selectedDoc?.identityKey,
      'page': updatedPin.page,
      // Keep both normalized and percentage coordinates for API mapping.
      'nx': updatedPin.nx,
      'ny': updatedPin.ny,
      'x_coordinate': updatedPin.nx * 100,
      'y_coordinate': updatedPin.ny * 100,
      'product_name': updatedPin.productName,
      'group_name': updatedPin.groupName,
      'block_name': updatedPin.blockName,
      'level_name': updatedPin.levelName,
      'plot_name': updatedPin.zoneLabel,
      'description': updatedPin.description,
      'quantity': updatedPin.quantity,
      'status': updatedPin.status,
      'variation': updatedPin.variation,
      'dropped_at': updatedPin.droppedAt?.toUtc().toIso8601String(),
    };
    final logLine = '[PinPayload] ${jsonEncode(payload)}';
    // ignore: avoid_print
    print(logLine);
    debugPrint(logLine);
  }

  PinEntry _pinWithMetadata(PinEntry geo, String? plotName) {
    final doc = _selectedDoc;
    final level = (doc?.levelName ?? '').trim();
    return PinEntry(
      nx: geo.nx,
      ny: geo.ny,
      page: geo.page,
      pdfPoint: geo.pdfPoint,
      productName: _selectedProduct?.trim(),
      groupName: _selectedGroup?.trim(),
      blockName: _blockName?.trim(),
      levelName: level.isEmpty ? null : level,
      zoneLabel: (plotName ?? '').trim().isEmpty ? null : plotName!.trim(),
      status: 'To Do',
      droppedAt: DateTime.now(),
    );
  }

  @override
  void initState() {
    super.initState();
    _imageTransform.addListener(_syncZoomFromImage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_bootstrap());
      }
    });
  }

  @override
  void dispose() {
    _disposePdfViewer();
    _imageTransform.removeListener(_syncZoomFromImage);
    _imageTransform.dispose();
    _searchController.dispose();
    _carouselScroll.dispose();
    super.dispose();
  }

  void _disposePdfViewer() {
    _pdfController?.removeListener(_syncZoomFromPdf);
    _pdfController?.dispose();
    _pdfController = null;
  }

  _UploadedDoc? get _selectedDoc =>
      _documents.isEmpty ? null : _documents[_selectedIndex];

  bool get _selectedIsPdf => _selectedDoc?.isPdf ?? false;

  void _syncZoomFromImage() {
    if (_selectedIsPdf || _selectedDoc == null) return;
    _applyZoomPercent(_imageTransform.value.getMaxScaleOnAxis());
  }

  void _syncZoomFromPdf() {
    if (!_selectedIsPdf || _pdfController == null) return;
    _applyZoomPercent(_pdfController!.zoomRatio);
    if (mounted) setState(() {});
  }

  void _applyZoomPercent(double scale) {
    final p = (scale * 100).round().clamp(25, 500);
    if (p != _zoomPercent && mounted) {
      setState(() => _zoomPercent = p);
    }
  }

  Offset _viewportCenter() {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.size.center(Offset.zero);
  }

  void _zoomImageBy(double multiplier) {
    if (_selectedDoc == null || _selectedIsPdf) return;

    final viewportCenter = _viewportCenter();
    final scenePoint = MatrixUtils.transformPoint(
      Matrix4.inverted(_imageTransform.value),
      viewportCenter,
    );

    const minScale = 0.25;
    const maxScale = 10.0;
    final current = _imageTransform.value.getMaxScaleOnAxis();
    final target = (current * multiplier).clamp(minScale, maxScale);
    final actualMult = target / current;
    if ((actualMult - 1).abs() < 0.001) return;

    final next = Matrix4.identity()
      ..translate(scenePoint.dx, scenePoint.dy)
      ..scale(actualMult)
      ..translate(-scenePoint.dx, -scenePoint.dy)
      ..multiply(_imageTransform.value);

    _imageTransform.value = next;
  }

  void _zoomPdfBy(double multiplier) {
    final ctrl = _pdfController;
    if (ctrl == null || !_selectedIsPdf) return;

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

  void _zoomIn() {
    if (_selectedDoc == null) return;
    if (_selectedIsPdf) {
      _zoomPdfBy(1.15);
    } else {
      _zoomImageBy(1.15);
    }
  }

  void _zoomOut() {
    if (_selectedDoc == null) return;
    if (_selectedIsPdf) {
      _zoomPdfBy(1 / 1.15);
    } else {
      _zoomImageBy(1 / 1.15);
    }
  }

  Future<void> _removeAllPinsForCurrentDoc() async {
    final markup = _markupForCurrentDoc;
    if (markup.pins.isEmpty) return;
    final n = markup.pins.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove all pins?'),
        content: Text(
          n == 1
              ? 'This will delete the pin on this document. This cannot be undone.'
              : 'This will delete all $n pins on this document. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      markup.pins.clear();
    });
    _onMarkupChanged();
  }

  void _reorderDocuments({required int fromIndex, required int toIndex}) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _documents.length ||
        toIndex >= _documents.length) {
      return;
    }

    setState(() {
      final moved = _documents.removeAt(fromIndex);
      _documents.insert(toIndex, moved);

      if (_selectedIndex == fromIndex) {
        _selectedIndex = toIndex;
      } else if (fromIndex < _selectedIndex && toIndex >= _selectedIndex) {
        _selectedIndex -= 1;
      } else if (fromIndex > _selectedIndex && toIndex <= _selectedIndex) {
        _selectedIndex += 1;
      }
    });

    _attachViewerForSelection();
    _scrollCarouselToIndex(_selectedIndex);
  }

  Future<void> _loadPdfMetadataForDoc(_UploadedDoc doc) async {
    if (!doc.isPdf) return;
    try {
      final cache = await PdfPageMetadataCache.fromFile(doc.path);
      if (!mounted) return;
      setState(() => _pdfMetadataByPath[doc.identityKey] = cache);
    } catch (_) {}
  }

  void _attachViewerForSelection() {
    _disposePdfViewer();
    _imageTransform.value = Matrix4.identity();

    final doc = _selectedDoc;
    if (doc == null) {
      setState(() => _zoomPercent = 100);
      return;
    }

    if (doc.isPdf) {
      final ctrl = PdfControllerPinch(document: PdfDocument.openFile(doc.path));
      ctrl.addListener(_syncZoomFromPdf);
      setState(() {
        _pdfController = ctrl;
        _zoomPercent = 100;
      });
      unawaited(_loadPdfMetadataForDoc(doc));
    } else {
      setState(() => _zoomPercent = 100);
    }
  }

  void _selectDocument(int index) {
    if (index < 0 || index >= _documents.length || index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
    _attachViewerForSelection();
    _scrollCarouselToIndex(index);
  }

  void _scrollCarouselToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_carouselScroll.hasClients) return;
      final step = _carouselCardSize + _carouselGap;
      final target = (index * step) - 24;
      _carouselScroll.animateTo(
        target.clamp(0.0, _carouselScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _carouselPrev() {
    if (_selectedIndex > 0) {
      _selectDocument(_selectedIndex - 1);
    }
  }

  Future<void> _bootstrap() async {
    if (!mounted || _didBootstrap) return;
    _didBootstrap = true;
    _projectId = widget.initialProjectId?.trim();
    _organizationId = widget.initialOrganizationId;
    _clientId = widget.initialClientId;
    _projectDescription = widget.initialProjectDescription?.trim();
    _startDate = widget.initialStartDate?.trim();
    _endDate = widget.initialEndDate?.trim();

    try {
      // Wait until this route is committed so dialogs stack above GoRouterâ€™s page
      // transition (showing the block dialog during the transition can fail silently).
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final storage = ref.read(localStorageProvider);
      final map = await QuotationsByBlockStore.readWithLegacyMigration(storage);

      if (widget.initialBlockName != null) {
        final name = widget.initialBlockName!.trim();
        if (name.isEmpty) {
          if (mounted && context.canPop()) context.pop();
          return;
        }
        if (!mounted) return;
        setState(() => _blockName = name);
        _restoreFromBlockMap(map);
        await _ensureProjectExistsForNewBlock(name);
        await _loadProjectLevelsFromBackendIfNeeded();
        await _seedInitialPdfIfNeeded();
        return;
      }

      if (!mounted) return;
      final chosen = await showBlockNameDialog(
        context,
        title: 'New block',
        subtitle: 'Name this block before adding quotation files.',
        initialValue: '',
        confirmLabel: 'Continue',
      );
      if (!mounted) return;
      if (chosen == null) {
        if (mounted && context.canPop()) context.pop();
        return;
      }
      setState(() => _blockName = chosen);
      _restoreFromBlockMap(map);
      await _ensureProjectExistsForNewBlock(chosen);
      await _loadProjectLevelsFromBackendIfNeeded();
      await _seedInitialPdfIfNeeded();
    } catch (e, st) {
      debugPrint('[QuoteProject] bootstrap error: $e\n$st');
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: AppStrings.apiErrorOpenCreateQuote,
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadProjectLevelsFromBackendIfNeeded() async {
    if (_documents.isNotEmpty) return;
    final projectId = (_projectId ?? '').trim();
    if (projectId.isEmpty) return;
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final levels = await api.fetchProjectLevels(projectId: projectId);
      if (!mounted || levels.isEmpty) return;

      final loadedDocs = <_UploadedDoc>[];
      final loadedMarkup = <String, QuoteDocMarkup>{};
      for (final level in levels) {
        final drawingPath = await _downloadRemoteDrawing(level);
        if (drawingPath == null || drawingPath.isEmpty) {
          continue;
        }
        final lower = drawingPath.toLowerCase();
        final doc = _UploadedDoc(
          path: drawingPath,
          displayName: drawingPath.split(Platform.pathSeparator).last,
          isPdf: lower.endsWith('.pdf'),
          levelName: level.name,
          levelId: level.id,
          remoteUri: level.drawingFile,
        );
        loadedDocs.add(doc);
        loadedMarkup[doc.identityKey] = _markupFromBackendPlots(
          levelName: level.name,
          plots: level.plots,
        );
      }
      if (!mounted || loadedDocs.isEmpty) return;
      setState(() {
        _documents
          ..clear()
          ..addAll(loadedDocs);
        _selectedIndex = 0;
        _markupByPath
          ..clear()
          ..addAll(loadedMarkup);
      });
      _attachViewerForSelection();
      _scrollCarouselToIndex(0);
    } catch (e) {
      debugPrint('[QuoteProject] level preload failed: $e');
    }
  }

  Future<String?> _downloadRemoteDrawing(ProjectLevelItem level) async {
    final uri = _resolveDrawingUri(level.drawingFile);
    if (uri == null) return null;
    try {
      final transfer = ref.read(dioMultipartTransferProvider);
      final res = await transfer.fetchBytes(
        uri,
        headers: _drawingFetchHeaders(),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final bytes = res.bodyBytes;
      if (bytes == null || bytes.isEmpty) return null;
      if (!_looksLikeSupportedDrawing(bytes)) return null;
      final fallbackName = 'level_${level.id}.pdf';
      final fileName = uri.pathSegments.isEmpty
          ? fallbackName
          : uri.pathSegments.last;
      return transfer.writeBytesToTempFile(bytes, fileName);
    } catch (_) {
      return null;
    }
  }

  Uri? _resolveDrawingUri(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final direct = Uri.tryParse(text);
    if (direct != null && direct.hasScheme) return direct;
    return Uri.parse(AppApiUrls.baseUrl).resolve(text);
  }

  Future<String> _ensureUploadDrawingPath(_UploadedDoc doc) async {
    final local = File(doc.path);
    if (await local.exists()) {
      return local.path;
    }
    final remote = (doc.remoteUri ?? '').trim();
    if (remote.isEmpty) {
      throw StateError(
        'Drawing file is missing locally for ${doc.displayName}. Please replace this file before submit.',
      );
    }
    final uri = _resolveDrawingUri(remote);
    if (uri == null) {
      throw StateError(
        'Invalid drawing URL for ${doc.displayName}. Please replace this file before submit.',
      );
    }
    final transfer = ref.read(dioMultipartTransferProvider);
    final res = await transfer.fetchBytes(uri, headers: _drawingFetchHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300 || res.bodyBytes == null) {
      throw StateError(
        'Could not fetch drawing for ${doc.displayName}. Please replace this file before submit.',
      );
    }
    final bytes = res.bodyBytes!;
    if (bytes.isEmpty) {
      throw StateError(
        'Empty drawing file for ${doc.displayName}. Please replace this file before submit.',
      );
    }
    if (!_looksLikeSupportedDrawing(bytes)) {
      throw StateError(
        'Downloaded drawing is not a valid image/pdf for ${doc.displayName}. Please replace this file before submit.',
      );
    }
    final fileName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : doc.displayName;
    return transfer.writeBytesToTempFile(bytes, fileName);
  }

  Map<String, String> _drawingFetchHeaders() {
    final storage = ref.read(localStorageProvider);
    final token = storage.getString(LocalStorageKeys.authAccessToken)?.trim();
    if (token == null || token.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  bool _looksLikeSupportedDrawing(List<int> bytes) {
    if (bytes.length < 4) return false;
    final isPdf =
        bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
    if (isPdf) return true;
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    if (isPng) return true;
    final isJpg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    if (isJpg) return true;
    final isGif =
        bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38;
    if (isGif) return true;
    final isWebp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return isWebp;
  }

  QuoteDocMarkup _markupFromBackendPlots({
    required String levelName,
    required List<Map<String, dynamic>> plots,
  }) {
    final markup = QuoteDocMarkup();
    for (final plot in plots) {
      final plotName = (plot['name'] as String?)?.trim() ?? '';
      final coordinatesRaw = plot['coordinates'];
      final points = _parseCoordinatesToOffsets(coordinatesRaw);
      if (points.length >= 3) {
        markup.polygons.add(
          PolyEntry(points: points, page: 1, plotName: plotName),
        );
      } else if (points.length == 2) {
        final a = points.first;
        final b = points.last;
        final rect = Rect.fromPoints(a, b);
        markup.boxHighlights.add(
          BoxEntry(n: rect, page: 1, plotName: plotName),
        );
      }
      final pinsRaw = plot['pins'];
      if (pinsRaw is! List) continue;
      for (final pinRaw in pinsRaw) {
        if (pinRaw is! Map) continue;
        final x = _asDouble(pinRaw['x_coordinate']);
        final y = _asDouble(pinRaw['y_coordinate']);
        if (x == null || y == null) continue;
        final pageRaw = plot['page'] ?? pinRaw['page'] ?? 1;
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
              cache: _pdfMetadataByPath.values.isEmpty
                  ? null
                  : _pdfMetadataByPath[_selectedDoc?.identityKey ?? ''],
            );
        if (pdfPoint != null) {
          markup.pins.add(
            PinEntry.fromAnnotation(
              pdfPoint,
              status: _statusFromId(pinRaw['status']),
              groupName: _groupFromId(pinRaw['group']),
              productName: _productFromId(pinRaw['composite_item']),
              quantity:
                  (_asDouble(pinRaw['quantity']) ?? 1).round().clamp(1, 9999),
              variation: (pinRaw['variation'] as bool?) == true ? 'Yes' : '',
              blockName: _blockName?.trim(),
              levelName: levelName,
              zoneLabel: plotName.isEmpty ? null : plotName,
              droppedAt: DateTime.now(),
            ),
          );
          continue;
        }
        final nx = (x > 1 ? x / 100.0 : x).clamp(0.0, 1.0);
        final ny = (y > 1 ? y / 100.0 : y).clamp(0.0, 1.0);
        markup.pins.add(
          PinEntry(
            nx: nx,
            ny: ny,
            page: page,
            status: _statusFromId(pinRaw['status']),
            groupName: _groupFromId(pinRaw['group']),
            productName: _productFromId(pinRaw['composite_item']),
            quantity: (_asDouble(pinRaw['quantity']) ?? 1).round().clamp(1, 9999),
            variation: (pinRaw['variation'] as bool?) == true ? 'Yes' : '',
            blockName: _blockName?.trim(),
            levelName: levelName,
            zoneLabel: plotName.isEmpty ? null : plotName,
            droppedAt: DateTime.now(),
          ),
        );
      }
    }
    return markup;
  }

  List<Offset> _parseCoordinatesToOffsets(dynamic coordinatesRaw) {
    if (coordinatesRaw is! List) return const <Offset>[];
    final out = <Offset>[];
    for (final point in coordinatesRaw) {
      if (point is! List || point.length < 2) continue;
      final x = _asDouble(point[0]);
      final y = _asDouble(point[1]);
      if (x == null || y == null) continue;
      out.add(
        Offset(
          (x > 1 ? x / 100.0 : x).clamp(0.0, 1.0),
          (y > 1 ? y / 100.0 : y).clamp(0.0, 1.0),
        ),
      );
    }
    return out;
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _statusFromId(dynamic idRaw) {
    final id = _asDouble(idRaw)?.round() ?? 1;
    if (id == 2) return 'In Progress';
    if (id == 3) return 'Done';
    return 'To Do';
  }

  String _groupFromId(dynamic idRaw) {
    final id = _asDouble(idRaw)?.round();
    if (id == null || id < 1 || id > QuoteSelectionOptions.groups.length) {
      return idRaw?.toString() ?? '1';
    }
    return QuoteSelectionOptions.groups[id - 1];
  }

  String _productFromId(dynamic idRaw) {
    final id = _asDouble(idRaw)?.round();
    if (id == null || id < 1 || id > QuoteSelectionOptions.products.length) {
      return idRaw?.toString() ?? '1';
    }
    return QuoteSelectionOptions.products[id - 1];
  }

  Future<void> _ensureProjectExistsForNewBlock(String blockName) async {
    if ((_projectId ?? '').trim().isNotEmpty) return;
    final api = ref.read(quoteProjectApiClientProvider);
    final projectId = await api.createProject(
      name: blockName,
      organizationId: _organizationId,
      clientId: _clientId,
      description: (_projectDescription ?? '').trim().isEmpty
          ? null
          : _projectDescription!.trim(),
      startDate: (_startDate ?? '').trim().isEmpty ? null : _startDate!.trim(),
      endDate: (_endDate ?? '').trim().isEmpty ? null : _endDate!.trim(),
    );
    if (!mounted) return;
    setState(() => _projectId = projectId);
    await _persistBlockQuotation();
  }

  Future<void> _seedInitialPdfIfNeeded() async {
    if (_didSeedInitialPdf || !mounted) return;
    _didSeedInitialPdf = true;
    final raw = widget.initialPdfUrl?.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (_documents.isNotEmpty) return;

    debugPrint('$_pdfLoadLogTag starting load from Get/Open button, url=$raw');
    setState(() => _isOpeningInitialPdf = true);
    try {
      final fallbackName = widget.initialPdfName?.trim().isNotEmpty == true
          ? widget.initialPdfName!.trim()
          : 'quote_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = fallbackName;
      debugPrint('$_pdfLoadLogTag resolved filename=$fileName');
      final downloadedPath = await downloadFile(uri, fileName: fileName);
      if (downloadedPath == null) {
        debugPrint(
          '$_pdfLoadLogTag download failed: no valid drawing file for url=$raw',
        );
        if (!mounted) return;
        context.showTopSnackBar(
          const SnackBar(
            content: Text(
              'Could not fetch drawing file from this link. Please upload file manually.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final file = File(downloadedPath);
      debugPrint(
        '$_pdfLoadLogTag downloaded file bytes=${await file.length()}, tempPath=${file.path}',
      );
      if (!mounted) return;
      final seededPins = _buildSeedPins(page: 1);
      final seededAreas = _buildSeedPlotAreas(page: 1);
      debugPrint(
        '$_pdfLoadLogTag seededPins=${seededPins.length}, seededAreas=${seededAreas.length}',
      );

      setState(() {
        final lower = file.path.toLowerCase();
        final seededDoc = _UploadedDoc(
          path: file.path,
          displayName: file.path.split(Platform.pathSeparator).last,
          isPdf: lower.endsWith('.pdf'),
          levelName: 'Level 1',
          remoteUri: raw,
        );
        _documents.add(seededDoc);
        if (seededPins.isNotEmpty || seededAreas.isNotEmpty) {
          _markupByPath[seededDoc.identityKey] = QuoteDocMarkup()
            ..polygons.addAll(seededAreas)
            ..pins.addAll(seededPins);
        }
        _selectedIndex = _documents.length - 1;
      });
      _attachViewerForSelection();
      _scrollCarouselToIndex(_selectedIndex);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            seededPins.isEmpty
                ? 'Drawing opened in Create Quote. You can now add pins/levels.'
                : 'Drawing opened with ${seededPins.length} auto pins.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      debugPrint('$_pdfLoadLogTag load success for fileName=$fileName');
    } catch (_) {
      debugPrint('$_pdfLoadLogTag load exception for url=$raw');
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Could not load drawing into Create Quote.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningInitialPdf = false);
      }
    }
  }

  Future<String?> downloadFile(
    Uri originalUri, {
    required String fileName,
  }) async {
    final transfer = ref.read(dioMultipartTransferProvider);
    final fetchHeaders = <String, String>{
      ..._drawingFetchHeaders(),
      'Accept': 'application/pdf,image/*,text/html,application/xhtml+xml,*/*',
      'User-Agent': 'Mozilla/5.0 (Flutter App)',
    };

    final candidates = <Uri>[
      originalUri,
      originalUri.replace(path: '${originalUri.path}/download'),
      originalUri.replace(
        queryParameters: <String, String>{
          ...originalUri.queryParameters,
          'download': '1',
        },
      ),
      if (originalUri.path.contains('/file/'))
        originalUri.replace(
          path: originalUri.path.replaceFirst('/file/', '/download/'),
        ),
    ];
    final visited = <String>{};

    for (var i = 0; i < candidates.length; i++) {
      final uri = candidates[i];
      if (!visited.add(uri.toString())) continue;
      debugPrint('$_pdfLoadLogTag trying candidate[$i]=$uri');
      try {
        final res = await transfer.fetchBytes(uri, headers: fetchHeaders);
        final status = res.statusCode;
        if (status < 200 || status >= 300) continue;
        final bytes = res.bodyBytes;
        if (bytes == null || bytes.isEmpty) continue;
        if (_looksLikeSupportedDrawing(bytes)) {
          final tempPath =
              await transfer.writeBytesToTempFile(bytes, fileName);
          debugPrint(
            '$_pdfLoadLogTag candidate[$i] valid drawing, status=$status, bytes=${bytes.length}',
          );
          return tempPath;
        }
        debugPrint(
          '$_pdfLoadLogTag candidate[$i] non-drawing response, status=$status, bytes=${bytes.length}',
        );
        final extracted = _extractPdfUriFromHtml(bytes, baseUri: uri);
        if (extracted != null && !visited.contains(extracted.toString())) {
          debugPrint(
            '$_pdfLoadLogTag extracted follow-up URL from HTML: $extracted',
          );
          candidates.add(extracted);
          if (extracted.path.contains('/file/')) {
            final asDownload = extracted.replace(
              path: extracted.path.replaceFirst('/file/', '/download/'),
            );
            if (!visited.contains(asDownload.toString())) {
              debugPrint(
                '$_pdfLoadLogTag added transformed /download URL: $asDownload',
              );
              candidates.add(asDownload);
            }
          }
        }
      } catch (e) {
        debugPrint('$_pdfLoadLogTag candidate[$i] threw: $e');
        // Try next candidate URL.
      }
    }

    debugPrint('$_pdfLoadLogTag all candidates exhausted without drawing');
    return null;
  }

  Uri? _extractPdfUriFromHtml(List<int> bytes, {required Uri baseUri}) {
    final html = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll(r'\/', '/');
    if (html.isEmpty) return null;

    final discovered = <Uri>[];

    void addCandidate(String raw) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) return;
      final parsed = Uri.tryParse(cleaned);
      if (parsed == null) return;
      final resolved = parsed.hasScheme ? parsed : baseUri.resolveUri(parsed);
      if (resolved.scheme != 'http' && resolved.scheme != 'https') return;
      discovered.add(resolved);
    }

    final attrMatches = RegExp(
      r'''(?:href|src|data-url|data-download-url)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html);
    for (final m in attrMatches) {
      addCandidate(m.group(1) ?? '');
    }

    final absoluteMatches = RegExp(
      r'''https?:\/\/[^\s"'<>\\]+''',
      caseSensitive: false,
    ).allMatches(html);
    for (final m in absoluteMatches) {
      addCandidate(m.group(0) ?? '');
    }

    for (final uri in discovered) {
      final lower = uri.toString().toLowerCase();
      if (lower.endsWith('.pdf') ||
          lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.gif') ||
          lower.contains('/download/')) {
        return uri;
      }
    }
    return discovered.isEmpty ? null : discovered.first;
  }

  int? _parseHexColorToArgb(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    var hex = text.startsWith('#') ? text.substring(1) : text;
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value;
  }

  List<PinEntry> _buildSeedPins({required int page}) {
    final rows = widget.initialProducts;
    if (rows == null || rows.isEmpty) return const [];
    final out = <PinEntry>[];
    for (final row in rows) {
      final xRaw = row['x_coordinate'];
      final yRaw = row['y_coordinate'];
      final x = xRaw is num ? xRaw.toDouble() : double.tryParse('$xRaw');
      final y = yRaw is num ? yRaw.toDouble() : double.tryParse('$yRaw');
      if (x == null || y == null) continue;

      // API sends coordinates as percentages in most payloads.
      final nx = (x > 1 ? x / 100.0 : x).clamp(0.0, 1.0);
      final ny = (y > 1 ? y / 100.0 : y).clamp(0.0, 1.0);

      final productName = (row['product_name'] as String?)?.trim();
      final levelName = (row['levels'] as String?)?.trim();
      final plotName = (row['plots'] as String?)?.trim();
      final qtyRaw = row['quantity'];
      final qty = qtyRaw is num ? qtyRaw.toInt() : int.tryParse('$qtyRaw') ?? 1;

      out.add(
        PinEntry(
          nx: nx,
          ny: ny,
          page: page,
          productName: productName,
          blockName: _blockName?.trim(),
          levelName: levelName?.isEmpty ?? true ? null : levelName,
          zoneLabel: plotName?.isEmpty ?? true ? null : plotName,
          quantity: qty < 1 ? 1 : qty,
          droppedAt: DateTime.now(),
        ),
      );
    }
    return out;
  }

  List<PolyEntry> _buildSeedPlotAreas({required int page}) {
    final rows = widget.initialProducts;
    if (rows == null || rows.isEmpty) return const [];
    final out = <PolyEntry>[];
    final seen = <String>{};

    for (final row in rows) {
      final rawPoints =
          row['plot_points'] ??
          row['Plot_points'] ??
          row['Plot_Points'] ??
          row['plot_x_coordinate'] ??
          row['Plot_X_Coordinate'];
      final points = _parsePlotPolygonPoints(rawPoints == null ? null : '$rawPoints');
      if (points == null || points.length < 3) continue;

      final plotColorRaw = row['plot_color'] ?? row['Plot_Color'];
      final colorValue = _parseHexColorToArgb(
        plotColorRaw == null ? null : '$plotColorRaw',
      );
      final plotNameRaw =
          row['Plot_name'] ??
          row['plot_name'] ??
          row['plots'] ??
          row['Location'] ??
          row['location'];
      final plotName = (plotNameRaw == null ? '' : '$plotNameRaw').trim();
      final key = '${points.map((e) => '${e.dx},${e.dy}').join('|')}|$plotName|$colorValue';
      if (!seen.add(key)) continue;

      out.add(
        PolyEntry(
          points: points,
          page: page,
          plotName: plotName,
          colorValue: colorValue,
        ),
      );
    }
    return out;
  }

  List<Offset>? _parsePlotPolygonPoints(String? raw) {
    if (raw == null) return null;
    final input = raw.trim();
    if (input.isEmpty) return null;
    final matches = RegExp(
      r'\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\]',
    ).allMatches(input);
    final points = <Offset>[];
    for (final m in matches) {
      final x = double.tryParse(m.group(1)!);
      final y = double.tryParse(m.group(2)!);
      if (x == null || y == null) continue;
      final nx = (x > 1 ? x / 100.0 : x).clamp(0.0, 1.0);
      final ny = (y > 1 ? y / 100.0 : y).clamp(0.0, 1.0);
      points.add(Offset(nx, ny));
    }
    return points.length < 3 ? null : points;
  }

  void _restoreFromBlockMap(QuotationsByBlock map) {
    final name = _blockName;
    if (name == null) return;

    final block = map[name];
    if (block == null) return;
    _sourceBlockName = name;
    _projectId = (block['projectId'] as String?)?.trim() ?? _projectId;
    _organizationId = block['organizationId'] as int? ?? _organizationId;
    _clientId = block['clientId'] as int? ?? _clientId;
    _projectDescription =
        (block['projectDescription'] as String?)?.trim() ?? _projectDescription;
    _startDate = (block['startDate'] as String?)?.trim() ?? _startDate;
    _endDate = (block['endDate'] as String?)?.trim() ?? _endDate;

    final docsJson = block['documents'] as List<dynamic>?;
    if (docsJson == null) return;

    final restored = <_UploadedDoc>[];
    for (final e in docsJson) {
      if (e is! Map) continue;
      final doc = _UploadedDoc.fromMap(Map<String, dynamic>.from(e));
      if (doc == null) continue;
      final hasRemote = (doc.remoteUri ?? '').trim().isNotEmpty;
      if (!hasRemote && !File(doc.path).existsSync()) continue;
      restored.add(doc);
    }
    if (restored.isEmpty) return;

    final idxRaw = block['selectedIndex'];
    var idx = 0;
    if (idxRaw is int) {
      idx = idxRaw.clamp(0, restored.length - 1);
    }

    _markupByPath.clear();
    final rawMarkup = block['markupByPath'];
    if (rawMarkup is Map) {
      for (final e in rawMarkup.entries) {
        final pathKey = e.key.toString();
        final v = e.value;
        if (v is Map<String, dynamic>) {
          _markupByPath[pathKey] = QuoteDocMarkup.fromJson(v);
        } else if (v is Map) {
          _markupByPath[pathKey] = QuoteDocMarkup.fromJson(
            Map<String, dynamic>.from(v),
          );
        }
      }
    }

    final sg = block['selectedGroup'];
    final sp = block['selectedProduct'];

    setState(() {
      _documents
        ..clear()
        ..addAll(restored);
      _selectedIndex = idx;
      _selectedGroup = sg is String ? sg : null;
      _selectedProduct = sp is String ? sp : null;
    });
    _attachViewerForSelection();
    _scrollCarouselToIndex(_selectedIndex);
  }

  void _carouselNext() {
    if (_selectedIndex < _documents.length - 1) {
      _selectDocument(_selectedIndex + 1);
    }
  }

  Future<void> _removeDocument(int index) async {
    if (index < 0 || index >= _documents.length) return;

    final removedPath = _documents[index].identityKey;

    setState(() {
      _documents.removeAt(index);
      _markupByPath.remove(removedPath);
      final len = _documents.length;
      if (len == 0) {
        _selectedIndex = 0;
        _disposePdfViewer();
        _imageTransform.value = Matrix4.identity();
        _zoomPercent = 100;
      } else {
        if (index < _selectedIndex) {
          _selectedIndex--;
        } else if (index == _selectedIndex) {
          _selectedIndex = index.clamp(0, len - 1);
        }
        _disposePdfViewer();
        _imageTransform.value = Matrix4.identity();
      }
    });

    if (_documents.isNotEmpty) {
      _attachViewerForSelection();
    }
  }

  Future<_UploadedDoc?> _materializePickedFile(PlatformFile file) async {
    final displayName = file.name.isNotEmpty
        ? file.name
        : (file.path?.split(Platform.pathSeparator).last ?? 'uploaded_file');
    final sanitizedName = displayName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final localPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        '${DateTime.now().microsecondsSinceEpoch}_$sanitizedName';
    final out = File(localPath);

    try {
      final sourcePath = file.path;
      if (sourcePath != null && sourcePath.trim().isNotEmpty) {
        final src = File(sourcePath);
        if (await src.exists()) {
          await src.copy(out.path);
        } else {
          final bytes = file.bytes;
          if (bytes == null || bytes.isEmpty) return null;
          await out.writeAsBytes(bytes, flush: true);
        }
      } else {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) return null;
        await out.writeAsBytes(bytes, flush: true);
      }
    } catch (_) {
      return null;
    }

    final lowerName = displayName.toLowerCase();
    final isPdf = lowerName.endsWith('.pdf');
    return _UploadedDoc(path: out.path, displayName: displayName, isPdf: isPdf);
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
      withData: true,
    );

    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final picked = <_UploadedDoc>[];
    for (final f in result.files) {
      final localDoc = await _materializePickedFile(f);
      if (localDoc != null) {
        picked.add(localDoc);
      }
    }
    if (picked.isEmpty) return;

    if (!mounted) return;
    final withLevels = <_UploadedDoc>[];
    for (final doc in picked) {
      if (!mounted) return;
      final levelName = await showInitializeLevelDialog(
        context,
        fileName: doc.displayName,
      );
      if (!mounted) return;
      if (levelName == null || levelName.isEmpty) {
        continue;
      }
      final levelId = await _syncLevelOnInitialize(
        levelName: levelName,
        drawingFilePath: doc.path,
      );
      if (!mounted) return;
      if (levelId == null) {
        continue;
      }
      withLevels.add(
        _UploadedDoc(
          path: doc.path,
          displayName: doc.displayName,
          isPdf: doc.isPdf,
          levelName: levelName,
          levelId: levelId,
        ),
      );
    }
    if (withLevels.isEmpty) {
      if (mounted) {
        context.showTopSnackBar(
          const SnackBar(
            content: Text(
              'Enter a level name for each file to add it to this quote.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _documents.addAll(withLevels);
      _selectedIndex = _documents.length - 1;
    });
    _attachViewerForSelection();
    _scrollCarouselToIndex(_selectedIndex);
  }

  Future<void> _replaceDocumentAt(int index) async {
    if (index < 0 || index >= _documents.length) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final replacementBase = await _materializePickedFile(result.files.first);
    if (!mounted || replacementBase == null) return;
    final displayName = replacementBase.displayName;
    final levelName = await showInitializeLevelDialog(
      context,
      fileName: displayName,
    );
    if (!mounted || levelName == null || levelName.isEmpty) return;
    final existing = _documents[index];
    final updatedLevelId = await _syncLevelOnInitialize(
      levelName: levelName,
      drawingFilePath: replacementBase.path,
      levelId: existing.levelId,
    );
    if (!mounted || updatedLevelId == null) return;

    final oldPath = _documents[index].identityKey;
    final replacement = _UploadedDoc(
      path: replacementBase.path,
      displayName: displayName,
      isPdf: replacementBase.isPdf,
      levelName: levelName,
      levelId: updatedLevelId,
    );

    setState(() {
      _documents[index] = replacement;
      _markupByPath.remove(oldPath);
      _selectedIndex = index;
    });
    _attachViewerForSelection();
    _scrollCarouselToIndex(index);
  }

  Future<String?> _syncLevelOnInitialize({
    required String levelName,
    required String drawingFilePath,
    String? levelId,
  }) async {
    var projectId = (_projectId ?? '').trim();
    if (projectId.isEmpty) {
      final blockName = (_blockName ?? '').trim();
      if (blockName.isNotEmpty) {
        await _ensureProjectExistsForNewBlock(blockName);
      }
      projectId = (_projectId ?? '').trim();
    }
    if (projectId.isEmpty) {
      if (mounted) {
        context.showTopSnackBar(
          const SnackBar(
            content: Text('Project is not ready yet. Try again in a moment.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }

    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final levelResult = await api.upsertLevel(
        projectId: projectId,
        levelId: levelId,
        levelName: levelName.trim().isEmpty ? 'Level' : levelName.trim(),
        drawingFilePath: drawingFilePath,
      );
      return levelResult.levelId;
    } catch (e) {
      if (mounted) {
        context.showTopSnackBar(
          SnackBar(
            content: Text(
              ApiResponseMessage.fromAnyError(
                e,
                genericFallback: 'Could not create level for this file.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _persistBlockQuotation({bool recordSubmitTime = false}) async {
    final name = _blockName;
    if (name == null) return;

    final storage = ref.read(localStorageProvider);
    var map = QuotationsByBlockStore.read(storage);

    if (_documents.isEmpty) {
      map.remove(name);
      await QuotationsByBlockStore.write(storage, map);
      return;
    }

    final markupByPath = <String, dynamic>{};
    for (final d in _documents) {
      final key = d.identityKey;
      final m = _markupByPath[key];
      if (m != null && !m.isEmpty) {
        markupByPath[key] = m.toJson();
      }
    }

    final entry = <String, dynamic>{
      'documents': _documents.map((e) => e.toJson()).toList(),
      'selectedIndex': _selectedIndex,
    };
    if ((_projectId ?? '').trim().isNotEmpty) {
      entry['projectId'] = _projectId!.trim();
    }
    if (_organizationId != null) {
      entry['organizationId'] = _organizationId;
    }
    if (_clientId != null) {
      entry['clientId'] = _clientId;
    }
    if ((_projectDescription ?? '').trim().isNotEmpty) {
      entry['projectDescription'] = _projectDescription!.trim();
    }
    if ((_startDate ?? '').trim().isNotEmpty) {
      entry['startDate'] = _startDate!.trim();
    }
    if ((_endDate ?? '').trim().isNotEmpty) {
      entry['endDate'] = _endDate!.trim();
    }
    if (_selectedGroup != null && _selectedGroup!.trim().isNotEmpty) {
      entry['selectedGroup'] = _selectedGroup!.trim();
    }
    if (_selectedProduct != null && _selectedProduct!.trim().isNotEmpty) {
      entry['selectedProduct'] = _selectedProduct!.trim();
    }
    if (markupByPath.isNotEmpty) {
      entry['markupByPath'] = markupByPath;
    }
    if (recordSubmitTime) {
      entry['submittedAt'] = DateTime.now().toUtc().toIso8601String();
    }
    final sourceName = _sourceBlockName?.trim();
    if (sourceName != null && sourceName.isNotEmpty && sourceName != name) {
      map.remove(sourceName);
    }
    map[name] = entry;
    await QuotationsByBlockStore.write(storage, map);
    _sourceBlockName = name;
  }

  int _statusToId(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s.contains('progress')) return 2;
    if (s.contains('done') || s.contains('complete')) return 3;
    return 1;
  }

  int _groupToId(String? groupName) {
    final value = (groupName ?? '').trim();
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
    final idx = QuoteSelectionOptions.groups.indexWhere(
      (e) => e.toLowerCase() == value.toLowerCase(),
    );
    return idx >= 0 ? idx + 1 : 1;
  }

  int _compositeItemToId(String? productName) {
    final value = (productName ?? '').trim();
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
    final idx = QuoteSelectionOptions.products.indexWhere(
      (e) => e.toLowerCase() == value.toLowerCase(),
    );
    return idx >= 0 ? idx + 1 : 1;
  }

  bool? _variationToBool(String? variation) {
    final value = (variation ?? '').trim().toLowerCase();
    if (value.isEmpty || value == 'no') return null;
    if (value == 'yes' || value == 'true') return true;
    if (value == 'false') return false;
    return null;
  }

  List<Map<String, dynamic>> _plotsPayloadForDoc(_UploadedDoc doc) {
    final markup = _markupByPath[doc.identityKey];
    if (markup == null) return const <Map<String, dynamic>>[];

    final namedPlots = <String, List<List<int>>>{};
    final namedPlotColors = <String, String>{};
    for (final box in markup.boxHighlights) {
      final name = box.plotName.trim();
      if (name.isEmpty) continue;
      final rect = box.n;
      namedPlots[name] = <List<int>>[
        [(rect.left * 100).round(), (rect.top * 100).round()],
        [(rect.right * 100).round(), (rect.bottom * 100).round()],
      ];
      if (box.colorValue != null) {
        final hex = box.colorValue!.toRadixString(16).padLeft(8, '0').substring(2);
        namedPlotColors[name] = '#$hex'.toUpperCase();
      }
    }
    for (final poly in markup.polygons) {
      final name = poly.plotName.trim();
      if (name.isEmpty) continue;
      namedPlots[name] = poly.points
          .map(
            (p) => <int>[
              (p.dx * 100).round(),
              (p.dy * 100).round(),
            ],
          )
          .toList();
      if (poly.colorValue != null) {
        final hex = poly.colorValue!.toRadixString(16).padLeft(8, '0').substring(2);
        namedPlotColors[name] = '#$hex'.toUpperCase();
      }
    }

    final pinsByPlot = <String, List<PinEntry>>{};
    for (final pin in markup.pins) {
      final plot = (pin.zoneLabel ?? '').trim();
      if (plot.isEmpty) continue;
      pinsByPlot.putIfAbsent(plot, () => <PinEntry>[]).add(pin);
    }

    final keys = <String>{...namedPlots.keys, ...pinsByPlot.keys}.toList()
      ..sort();
    final plots = <Map<String, dynamic>>[];
    for (final plotName in keys) {
      final pins = pinsByPlot[plotName] ?? const <PinEntry>[];
        final pinPayload = <Map<String, dynamic>>[];
      for (var p = 0; p < pins.length; p++) {
        final pin = pins[p];
        final engine = _pdfEngine;
        final coords = pin.pdfPoint != null
            ? PdfCoordinateCodec.annotationToApi(pin.pdfPoint!)
            : (engine != null
                  ? PdfCoordinateCodec.annotationToApi(
                      PdfAnnotationPoint(
                        page: pin.page ?? 1,
                        pdfX: pin.nx * (engine.metadata.page(pin.page ?? 1)?.width ?? 1),
                        pdfY: pin.ny * (engine.metadata.page(pin.page ?? 1)?.height ?? 1),
                        pageWidth: engine.metadata.page(pin.page ?? 1)?.width ?? 1,
                        pageHeight: engine.metadata.page(pin.page ?? 1)?.height ?? 1,
                      ),
                    )
                  : {
                      'x_coordinate': (pin.nx * 100).round(),
                      'y_coordinate': (pin.ny * 100).round(),
                    });
        final payload = <String, dynamic>{
          ...coords,
          if (pin.page != null) 'page': pin.page,
          'status': _statusToId(pin.status),
          'group': _groupToId(pin.groupName),
          'composite_item': _compositeItemToId(pin.productName),
          'quantity': pin.quantity < 1 ? 1 : pin.quantity,
        };
        final variation = _variationToBool(pin.variation);
        if (variation != null) {
          payload['variation'] = variation;
        }
        pinPayload.add(payload);
      }

      plots.add(<String, dynamic>{
        'name': plotName,
        'coordinates': namedPlots[plotName] ?? const <List<int>>[],
        if (namedPlotColors.containsKey(plotName))
          'plot_color': namedPlotColors[plotName],
        'pins': pinPayload,
      });
    }
    return plots;
  }

  Future<void> _submitQuotation() async {
    if (_isSubmitting) return;
    final name = _blockName?.trim();
    if (name == null || name.isEmpty) {
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(content: Text('Set a block name before submitting.')),
      );
      return;
    }
    if (_documents.isEmpty) {
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Add at least one file before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      var projectId = (_projectId ?? widget.initialProjectId ?? '').trim();
      if (projectId.isEmpty) {
        projectId = await api.createProject(
          name: name,
          organizationId: _organizationId,
          clientId: _clientId,
          description: (_projectDescription ?? '').trim().isEmpty
              ? null
              : _projectDescription!.trim(),
          startDate: (_startDate ?? '').trim().isEmpty ? null : _startDate!.trim(),
          endDate: (_endDate ?? '').trim().isEmpty ? null : _endDate!.trim(),
        );
      } else {
        await api.updateProject(projectId: projectId, name: name);
      }

      final synced = <_UploadedDoc>[];
      for (final doc in _documents) {
        final drawingPath = await _ensureUploadDrawingPath(doc);
        var levelId = (doc.levelId ?? '').trim();
        if (levelId.isEmpty) {
          final levelResult = await api.upsertLevel(
            projectId: projectId,
            levelId: doc.levelId,
            levelName: doc.levelName.trim().isEmpty
                ? doc.displayName
                : doc.levelName,
            drawingFilePath: drawingPath,
          );
          levelId = (levelResult.levelId ?? '').trim();
        }
        if (levelId.isEmpty) {
          throw StateError('Level id missing for ${doc.displayName}.');
        }
        final plotsPayload = _plotsPayloadForDoc(doc);
        await api.updateLevelPlots(
          projectId: projectId,
          levelId: levelId,
          plots: plotsPayload,
        );
        synced.add(
          _UploadedDoc(
            path: drawingPath,
            displayName: doc.displayName,
            isPdf: doc.isPdf,
            levelName: doc.levelName,
            levelId: levelId,
            remoteUri: doc.remoteUri,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _projectId = projectId;
        _documents
          ..clear()
          ..addAll(synced);
      });

      await _persistBlockQuotation(recordSubmitTime: true);
      if (!mounted) return;

      context.showTopSnackBar(
        SnackBar(
          content: Text('Quote saved to levels successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go(DashboardPage.path);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not sync project/levels right now.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _canvasToolButton({
    required QuoteCanvasTool tool,
    required IconData icon,
    required String tip,
  }) {
    final enabled = _documents.isNotEmpty;
    final active = _canvasTool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tip,
        child: _ToolIcon(
          icon: icon,
          isActive: active,
          onTap: enabled ? () => setState(() => _canvasTool = tool) : null,
        ),
      ),
    );
  }

  Widget _removeAllPinsButton() {
    final enabled =
        _documents.isNotEmpty && _markupForCurrentDoc.pins.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: enabled ? 'Remove all pins' : 'No pins to remove',
        child: _ToolIcon(
          icon: Icons.delete_sweep_outlined,
          onTap: enabled
              ? () => unawaited(_removeAllPinsForCurrentDoc())
              : null,
        ),
      ),
    );
  }

  Widget _reorderFilesRow(BuildContext context) {
    if (_documents.isEmpty) return const SizedBox.shrink();

    String shortTitle(String name) {
      final base = name.replaceAll(RegExp(r'\.[^.]+$'), '');
      if (base.length <= 14) return base;
      return '${base.substring(0, 12)}..';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(_documents.length, (index) {
          final selected = index == _selectedIndex;
          final chip = AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF111827)
                    : const Color(0xFFD1D5DB),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.drag_indicator,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  '${index + 1}',
                  style: AppFonts.labelSmall(
                        color: selected ? Colors.white : AppColors.muted,
                      ).copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 6),
                Text(
                  shortTitle(_documents[index].displayName),
                  style: AppFonts.labelSmall(
                        color: selected ? Colors.white : AppColors.ink,
                      ).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          );

          return Padding(
            padding: EdgeInsets.only(
              right: index == _documents.length - 1 ? 0 : 6,
            ),
            child: DragTarget<int>(
              onWillAcceptWithDetails: (details) => details.data != index,
              onAcceptWithDetails: (details) {
                _reorderDocuments(fromIndex: details.data, toIndex: index);
              },
              builder: (context, candidateData, rejectedData) {
                final highlighted = candidateData.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: highlighted
                      ? const EdgeInsets.all(2)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: highlighted
                        ? const Color(0x1434D399)
                        : Colors.transparent,
                  ),
                  child: GestureDetector(
                    onTap: () => _selectDocument(index),
                    child: LongPressDraggable<int>(
                      data: index,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Opacity(opacity: 0.9, child: chip),
                      ),
                      childWhenDragging: Opacity(opacity: 0.4, child: chip),
                      child: chip,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyTopPad = AppLayout.quoteProjectBodyTop(context);
    return Scaffold(
      backgroundColor: AppColors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBarStyles.transparent(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.inkStrong),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        titleSpacing: 8,
        title: Text(
          'Create quote to project',
          style: AppFonts.titleMedium(color: AppColors.ink).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _showSearchField ? 170 : 44,
            margin: const EdgeInsets.only(right: 8),
            child: _showSearchField
                ? AppTextField(
                    controller: _searchController,
                    autofocus: true,
                    dense: true,
                    hintText: 'Search records',
                    prefixIcon: Icons.search,
                    hintStyle:
                        AppFonts.bodySmall(color: AppColors.textFieldHint)
                            .copyWith(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                  )
                : IconButton(
                    onPressed: () {
                      setState(() {
                        _showSearchField = true;
                      });
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    icon: const Icon(Icons.search, color: Color(0xFF1F2937)),
                  ),
          ),
          IconButton(
            onPressed: () async {
              if (_showSearchField) {
                setState(() {
                  _showSearchField = false;
                  _searchController.clear();
                });
                return;
              }

              final current = _blockName;
              if (current == null) return;
              final next = await showBlockNameDialog(
                context,
                title: 'Update block name',
                subtitle: 'Rename this quotation block.',
                initialValue: current,
                confirmLabel: 'Save',
              );
              if (!mounted || next == null || next == current) return;

              setState(() => _blockName = next);
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            icon: Icon(
              _showSearchField ? Icons.close : Icons.edit_outlined,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppScreenStack(
        child: Padding(
        padding: EdgeInsets.fromLTRB(10, bodyTopPad, 10, 90),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _canvasToolButton(
                        tool: QuoteCanvasTool.select,
                        icon: Icons.near_me_outlined,
                        tip: 'Select',
                      ),
                      _canvasToolButton(
                        tool: QuoteCanvasTool.pan,
                        icon: Icons.pan_tool_alt_outlined,
                        tip: 'Pan & move',
                      ),
                      _canvasToolButton(
                        tool: QuoteCanvasTool.box,
                        icon: Icons.crop_square_outlined,
                        tip: 'Box highlight',
                      ),
                      _canvasToolButton(
                        tool: QuoteCanvasTool.polygon,
                        icon: Icons.polyline,
                        tip: 'Polygon â€” double-tap to finish',
                      ),
                      _canvasToolButton(
                        tool: QuoteCanvasTool.placePin,
                        icon: Icons.location_on_outlined,
                        tip: 'Place pin',
                      ),
                      _removeAllPinsButton(),
                      const SizedBox(width: 10),
                      _ToolIcon(
                        icon: Icons.zoom_in_outlined,
                        onTap: _documents.isEmpty ? null : _zoomIn,
                      ),
                      _ZoomText(text: '$_zoomPercent%'),
                      _ToolIcon(
                        icon: Icons.zoom_out_outlined,
                        onTap: _documents.isEmpty ? null : _zoomOut,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_documents.isNotEmpty) ...[
              _reorderFilesRow(context),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  radius: const Radius.circular(16),
                  strokeWidth: 2,
                  color: const Color(0xFFD1D5DB),
                  dashPattern: const [8, 4],
                  stackFit: StackFit.expand,
                ),
                child: Container(
                  key: _canvasKey,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFE5E7EB),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildGround(context),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_documents.isNotEmpty) ...[
                  _DocumentCarousel(
                    documents: _documents,
                    selectedIndex: _selectedIndex,
                    scrollController: _carouselScroll,
                    onSelect: _selectDocument,
                    onRemove: _removeDocument,
                    onReplace: _replaceDocumentAt,
                    onPrev: _carouselPrev,
                    onNext: _carouselNext,
                  ),
                  const SizedBox(height: 10),
                ],
                Builder(
                  builder: (context) {
                    final canSubmit =
                        (_blockName ?? '').trim().isNotEmpty &&
                        _documents.isNotEmpty &&
                        !_isSubmitting;
                    return Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Upload PDF',
                            icon: Icons.upload_file_outlined,
                            onPressed: _pickDocument,
                            height: 44,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: _isSubmitting
                                ? 'Syncing...'
                                : 'Submit (${_documents.length})',
                            icon: Icons.send_outlined,
                            onPressed: canSubmit
                                ? () => unawaited(_submitQuotation())
                                : null,
                            height: 44,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _BottomTag(
                      label: 'BLOCK',
                      value: (_blockName ?? '').trim().isNotEmpty
                          ? _blockName!.trim()
                          : 'N/A',
                    ),
                    const SizedBox(width: 6),
                    _BottomTag(
                      label: 'LEVEL',
                      value:
                          _selectedDoc != null &&
                              _selectedDoc!.levelName.isNotEmpty
                          ? _selectedDoc!.levelName
                          : 'N/A',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _BottomSelectTag(
                      label: 'GROUP',
                      placeholder: 'â€” Select Group â€”',
                      options: QuoteSelectionOptions.groups,
                      selected: _selectedGroup,
                      onChanged: (v) {
                        setState(() => _selectedGroup = v);
                      },
                    ),
                    const SizedBox(width: 6),
                    _BottomSelectTag(
                      label: 'PRODUCT',
                      placeholder: 'â€” Select Product â€”',
                      options: QuoteSelectionOptions.products,
                      selected: _selectedProduct,
                      onChanged: (v) {
                        setState(() => _selectedProduct = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGround(BuildContext context) {
    final doc = _selectedDoc;
    if (_isOpeningInitialPdf && doc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w =
                  (constraints.maxWidth * 0.92).clamp(220.0, 340.0).toDouble();
              final previewH = w * 4 / 3;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSkeletonBox(
                    width: w,
                    height: previewH,
                    borderRadius: 12,
                  ),
                  const SizedBox(height: 22),
                  AppSkeletonLine(height: 18, widthFactor: 0.75),
                  const SizedBox(height: 10),
                  AppSkeletonLine(height: 14, widthFactor: 0.55),
                  const SizedBox(height: 6),
                  Text(
                    'Opening PDF from URLâ€¦',
                    textAlign: TextAlign.center,
                    style:
                        AppFonts.bodySmall(color: AppColors.muted).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }
    if (doc == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFE5E7EB),
              child: Icon(
                Icons.description_outlined,
                color: Color(0xFF374151),
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Documents Added',
              style: AppFonts.headlineSmall(color: AppColors.ink).copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload PDFs (multiple) to begin mapping\nplots and placing equipment pins.',
              textAlign: TextAlign.center,
              style: AppFonts.bodyLarge(color: AppColors.muted).copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
            ),
          ],
        ),
      );
    }

    if (_selectedIsPdf && _pdfController != null) {
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          PdfViewPinch(
            controller: _pdfController!,
            minScale: 0.5,
            maxScale: 8,
            scrollDirection: Axis.vertical,
            padding: 8,
            backgroundDecoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
          ),
          Positioned.fill(
            child: QuoteCanvasMarkupLayer(
              tool: _canvasTool,
              markup: _markupForCurrentDoc,
              onMarkupChanged: _onMarkupChanged,
              onPinPlacementRejected: _onPinPlacementRejected,
              onPlotAreaNamed: () => showNewPlotNameDialog(context),
              onManagePlotArea:
                  ({
                    required bool isBox,
                    required int index,
                    required String initialName,
                  }) => showManagePlotAreaDialog(
                    context,
                    initialName: initialName,
                  ),
              pdfController: _pdfController,
              pdfEngine: _pdfEngine,
              isPdf: true,
              showPinsOnCanvas: true,
              pinPrerequisitesMet: _pinContextReady,
              pinMetadataBuilder: _pinWithMetadata,
              onPinTapped: _openPinDetail,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
    }

    return InteractiveViewer(
      transformationController: _imageTransform,
      panEnabled: _canvasTool == QuoteCanvasTool.pan,
      scaleEnabled: true,
      minScale: 0.25,
      maxScale: 10,
      constrained: true,
      clipBehavior: Clip.hardEdge,
      boundaryMargin: const EdgeInsets.all(48),
      child: QuoteCanvasMarkupLayer(
        tool: _canvasTool,
        markup: _markupForCurrentDoc,
        onMarkupChanged: _onMarkupChanged,
        onPinPlacementRejected: _onPinPlacementRejected,
        onPlotAreaNamed: () => showNewPlotNameDialog(context),
        onManagePlotArea:
            ({
              required bool isBox,
              required int index,
              required String initialName,
            }) => showManagePlotAreaDialog(context, initialName: initialName),
        isPdf: false,
        showPinsOnCanvas: true,
        pinPrerequisitesMet: _pinContextReady,
        pinMetadataBuilder: _pinWithMetadata,
        onPinTapped: _openPinDetail,
        child: Center(
          child: Image.file(
            File(doc.path),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this file.',
                  textAlign: TextAlign.center,
                  style: AppFonts.bodyMedium(color: AppColors.muted),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
