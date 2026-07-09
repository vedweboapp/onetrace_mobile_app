import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
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
  });

  final String cacheKey;
  final String? remoteDrawingUrl;
  final String? fallbackTitle;

  @override
  ConsumerState<EmployeeJobDrawingPreview> createState() =>
      _EmployeeJobDrawingPreviewState();
}

class _EmployeeJobDrawingPreviewState
    extends ConsumerState<EmployeeJobDrawingPreview> {
  static final Map<String, Uint8List?> _memoryCache = <String, Uint8List?>{};

  Uint8List? _bytes;
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
        _loading = false;
      });
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

    if (key.isNotEmpty) _memoryCache[key] = rendered;
    if (!mounted) return;
    setState(() {
      _bytes = rendered;
      _loading = false;
    });
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
        child: Image.memory(
          _bytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _placeholder(widget.fallbackTitle),
        ),
      );
    }

    return _placeholder(widget.fallbackTitle);
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

class _PlaceholderDrawingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF3F4F6),
    );

    final grid = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1;

    const step = 18.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final plan = Paint()
      ..color = AppColors.inkStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.18,
      size.width * 0.76,
      size.height * 0.58,
    );
    canvas.drawRect(rect, plan);
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      plan,
    );
    canvas.drawLine(
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      plan,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
