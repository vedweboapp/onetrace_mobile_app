import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Counts pins across all plots on a level (`plots[].pins[]`).
int pinCountFromLevelPlots(List<Map<String, dynamic>> plots) {
  var count = 0;
  for (final plot in plots) {
    final pins = plot['pins'];
    if (pins is List) count += pins.length;
  }
  return count;
}

/// Square preview: PDF/image thumbnail with a centered pin and pin count.
class LevelDrawingThumbnail extends ConsumerStatefulWidget {
  const LevelDrawingThumbnail({
    super.key,
    required this.cacheKey,
    this.remoteDrawingUrl,
    this.localFilePath,
    required this.pinCount,
    this.size = 54,
  });

  final String cacheKey;
  final String? remoteDrawingUrl;
  final String? localFilePath;
  final int pinCount;
  final double size;

  @override
  ConsumerState<LevelDrawingThumbnail> createState() =>
      _LevelDrawingThumbnailState();
}

class _LevelDrawingThumbnailState extends ConsumerState<LevelDrawingThumbnail> {
  static final Map<String, Uint8List?> _memoryCache = <String, Uint8List?>{};

  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveThumbnail();
  }

  @override
  void didUpdateWidget(covariant LevelDrawingThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.remoteDrawingUrl != widget.remoteDrawingUrl ||
        oldWidget.localFilePath != widget.localFilePath) {
      _resolveThumbnail();
    }
  }

  Future<void> _resolveThumbnail() async {
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
      if (path != null && path.isNotEmpty) {
        rendered = await _renderFileThumbnail(path, widget.size);
      }
    } catch (_) {
      rendered = null;
    }

    if (key.isNotEmpty) {
      _memoryCache[key] = rendered;
    }
    if (!mounted) return;
    setState(() {
      _bytes = rendered;
      _loading = false;
    });
  }

  Future<String?> _resolveLocalPath() async {
    final local = (widget.localFilePath ?? '').trim();
    if (local.isNotEmpty && File(local).existsSync()) return local;

    final remote = (widget.remoteDrawingUrl ?? '').trim();
    if (remote.isEmpty) return null;

    final api = ref.read(quoteProjectApiClientProvider);
    return api.downloadDrawingForLocalEdit(remote);
  }

  static bool _isPdfPath(String path) =>
      path.toLowerCase().endsWith('.pdf');

  static bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  static Future<Uint8List?> _renderFileThumbnail(
    String path,
    double displaySize,
  ) async {
    if (_isPdfPath(path)) {
      final doc = await PdfDocument.openFile(path);
      try {
        final page = await doc.getPage(1);
        try {
          final targetW = (displaySize * 2).clamp(64.0, 256.0);
          final aspect = page.height > 0 ? page.width / page.height : 1.0;
          final targetH = targetW / aspect;
          final image = await page.render(
            width: targetW,
            height: targetH,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: 72,
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
    final size = widget.size;
    final pinSize = size * 0.56;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D31),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E2E4)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_loading)
                const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  ),
                )
              else if (_bytes != null)
                Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _placeholderBody(size),
                )
              else
                _placeholderBody(size),
              // Slight dim so the pin reads on bright drawings.
              Container(color: Colors.black.withValues(alpha: 0.18)),
              Center(child: _pinBadge(pinSize, widget.pinCount)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderBody(double size) {
    return ColoredBox(
      color: const Color(0xFF2A2D31),
      child: Icon(
        Icons.picture_as_pdf_rounded,
        color: AppColors.white.withValues(alpha: 0.55),
        size: size * 0.38,
      ),
    );
  }

  Widget _pinBadge(double pinSize, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: pinSize,
          height: pinSize * 1.22,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Icon(
                Icons.push_pin_rounded,
                size: pinSize,
                color: AppColors.white.withValues(alpha: 0.95),
              ),
              Positioned(
                top: pinSize * 0.14,
                child: Container(
                  width: pinSize * 0.62,
                  height: pinSize * 0.62,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF111216),
                  ),
                  child: Text(
                    '$count',
                    style: AppFonts.labelMedium(color: AppColors.white).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: pinSize * 0.36,
                      height: 1,
                    ),
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
