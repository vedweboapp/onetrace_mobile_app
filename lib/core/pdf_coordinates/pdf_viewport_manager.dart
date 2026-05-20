import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

import 'pdf_coordinate_engine.dart';
import 'pdf_page_metadata_cache.dart';

/// Owns PDF controller + page metadata + [PdfCoordinateEngine].
///
/// Notifies [onViewportChanged] whenever the pdfx matrix changes (zoom/pan/scroll)
/// so pin overlays can recalculate screen positions.
class PdfViewportManager extends ChangeNotifier {
  PdfViewportManager();

  PdfControllerPinch? _controller;
  PdfPageMetadataCache? _metadata;

  PdfControllerPinch? get controller => _controller;
  PdfPageMetadataCache? get metadata => _metadata;

  PdfCoordinateEngine? get engine {
    final c = _controller;
    final m = _metadata;
    if (c == null || m == null) return null;
    return PdfCoordinateEngine(controller: c, metadata: m);
  }

  bool get isReady => _controller != null && _metadata != null;

  VoidCallback? onViewportChanged;

  void _onMatrixChanged() {
    onViewportChanged?.call();
    notifyListeners();
  }

  /// Binds an open document path; loads page width/height/rotation metadata.
  Future<void> attachFile(String path) async {
    detach();
    final ctrl = PdfControllerPinch(document: PdfDocument.openFile(path));
    ctrl.addListener(_onMatrixChanged);
    _controller = ctrl;
    try {
      _metadata = await PdfPageMetadataCache.fromFile(path);
    } catch (_) {
      _metadata = PdfPageMetadataCache();
    }
    notifyListeners();
  }

  void attach({
    required PdfControllerPinch controller,
    required PdfPageMetadataCache metadata,
  }) {
    detach();
    controller.addListener(_onMatrixChanged);
    _controller = controller;
    _metadata = metadata;
    notifyListeners();
  }

  void detach() {
    _controller?.removeListener(_onMatrixChanged);
    _controller?.dispose();
    _controller = null;
    _metadata = null;
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
