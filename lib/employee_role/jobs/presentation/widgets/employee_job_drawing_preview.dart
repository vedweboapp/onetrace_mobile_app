import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/pdf_coordinates/pdf_coordinate_codec.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Wide drawing preview for operative drawing cards (PDF/image first page).
class EmployeeJobDrawingPreview extends ConsumerStatefulWidget {
  const EmployeeJobDrawingPreview({
    super.key,
    required this.cacheKey,
    this.remoteDrawingUrl,
    this.fallbackTitle,
    this.pins = const [],
  });

  final String cacheKey;
  final String? remoteDrawingUrl;
  final String? fallbackTitle;

  /// Pins to overlay on the thumbnail (API `x_coordinate` / `y_coordinate`).
  final List<EmployeeJobDrawingPin> pins;

  @override
  ConsumerState<EmployeeJobDrawingPreview> createState() =>
      _EmployeeJobDrawingPreviewState();
}

class _EmployeeJobDrawingPreviewState
    extends ConsumerState<EmployeeJobDrawingPreview> {
  static final Map<String, Uint8List?> _memoryCache = <String, Uint8List?>{};
  static final Map<String, Size> _sizeCache = <String, Size>{};

  Uint8List? _bytes;
  Size? _imageSize;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant EmployeeJobDrawingPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.remoteDrawingUrl != widget.remoteDrawingUrl) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final key = widget.cacheKey.trim();
    if (key.isNotEmpty && _memoryCache.containsKey(key)) {
      if (!mounted) return;
      setState(() {
        _bytes = _memoryCache[key];
        _imageSize = _sizeCache[key];
        _loading = false;
      });
      if (_bytes != null && _imageSize == null) {
        unawaited(_ensureImageSize(key, _bytes!));
      }
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    Uint8List? rendered;
    try {
      final path = await _resolveLocalPath();
      if (path != null) {
        rendered = await _renderFileThumbnail(path);
      }
    } catch (_) {
      rendered = null;
    }

    Size? size;
    if (rendered != null) {
      size = await _decodeImageSize(rendered);
    }

    if (key.isNotEmpty) {
      _memoryCache[key] = rendered;
      if (size != null) _sizeCache[key] = size;
    }
    if (!mounted) return;
    setState(() {
      _bytes = rendered;
      _imageSize = size;
      _loading = false;
    });
  }

  Future<void> _ensureImageSize(String key, Uint8List bytes) async {
    final size = await _decodeImageSize(bytes);
    if (size == null || !mounted) return;
    _sizeCache[key] = size;
    setState(() => _imageSize = size);
  }

  static Future<Size?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveLocalPath() async {
    final remote = resolveEmployeeDrawingFileUrl(widget.remoteDrawingUrl) ?? '';
    if (remote.isEmpty) return null;
    final api = ref.read(quoteProjectApiClientProvider);
    return api.downloadDrawingForLocalEdit(remote);
  }

  static bool _isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

  static bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  static Future<Uint8List?> _renderFileThumbnail(String path) async {
    if (_isPdfPath(path)) {
      final doc = await PdfDocument.openFile(path);
      try {
        final page = await doc.getPage(1);
        try {
          const targetW = 640.0;
          final aspect = page.height > 0 ? page.width / page.height : 1.0;
          final targetH = targetW / aspect;
          final image = await page.render(
            width: targetW,
            height: targetH,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: 80,
          );
          return image?.bytes;
        } finally {
          await page.close();
        }
      } finally {
        await doc.close();
      }
    }
    if (_isImagePath(path)) {
      return File(path).readAsBytes();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFFF3F4F6),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_bytes != null) {
      return ColoredBox(
        color: const Color(0xFFF3F4F6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) =>
                      _placeholder(widget.fallbackTitle),
                ),
                if (widget.pins.isNotEmpty && _imageSize != null)
                  ..._buildPinOverlays(box, _imageSize!),
              ],
            );
          },
        ),
      );
    }

    return _placeholder(widget.fallbackTitle);
  }

  List<Widget> _buildPinOverlays(Size box, Size imageSize) {
    if (box.width <= 0 || box.height <= 0) return const [];
    if (imageSize.width <= 0 || imageSize.height <= 0) return const [];

    final fitted = applyBoxFit(BoxFit.cover, imageSize, box);
    final dest = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & box,
    );
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & imageSize,
    );

    const pinSize = 18.0;
    final overlays = <Widget>[];
    for (var i = 0; i < widget.pins.length; i++) {
      final pin = widget.pins[i];
      final nx = PdfCoordinateCodec.normalizeApiScalar(pin.xCoordinate);
      final ny = PdfCoordinateCodec.normalizeApiScalar(pin.yCoordinate);
      final imageX = nx * imageSize.width;
      final imageY = ny * imageSize.height;
      final localX =
          dest.left + ((imageX - source.left) / source.width) * dest.width;
      final localY =
          dest.top + ((imageY - source.top) / source.height) * dest.height;

      final label = pin.location.trim().isNotEmpty
          ? pin.location.trim()
          : '${i + 1}';

      overlays.add(
        Positioned(
          left: localX - pinSize / 2,
          top: localY - pinSize,
          width: pinSize,
          height: pinSize,
          child: IgnorePointer(
            child: _PreviewPinMarker(
              background: pin.statusBackground,
              foreground: pin.statusForeground,
              label: label,
            ),
          ),
        ),
      );
    }
    return overlays;
  }

  Widget _placeholder(String? title) {
    return CustomPaint(
      painter: _PlaceholderDrawingPainter(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            title ?? 'Drawing',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.labelLarge(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _PreviewPinMarker extends StatelessWidget {
  const _PreviewPinMarker({
    required this.background,
    required this.foreground,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label.length > 2 ? label.substring(0, 2) : label,
          style: TextStyle(
            color: foreground,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _PlaceholderDrawingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF3F4F6);
    canvas.drawRect(Offset.zero & size, bg);
    final grid = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final accent = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.5;
    final rect = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.22,
      size.width * 0.64,
      size.height * 0.56,
    );
    canvas.drawRect(rect, accent);
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      accent,
    );
    canvas.drawLine(
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
