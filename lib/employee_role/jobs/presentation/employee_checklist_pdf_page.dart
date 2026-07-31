import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Read-only file viewer for operative checklist / pin attachments (PDF, PNG, JPG, etc.).
class EmployeeChecklistPdfPage extends ConsumerStatefulWidget {
  const EmployeeChecklistPdfPage({
    super.key,
    required this.title,
    required this.fileUrl,
    this.heroTag,
  });

  static const path = '/employee-role/jobs/checklist-pdf';
  static const name = 'employee-checklist-pdf';

  final String title;
  final String fileUrl;

  /// Optional shared element tag for the open-attachment transition.
  final String? heroTag;

  @override
  ConsumerState<EmployeeChecklistPdfPage> createState() =>
      _EmployeeChecklistPdfPageState();
}

class _EmployeeChecklistPdfPageState
    extends ConsumerState<EmployeeChecklistPdfPage> {
  PdfControllerPinch? _pdfController;
  String? _localPath;
  var _loading = true;
  String? _errorMessage;

  bool get _isPdf => _pdfController != null;

  bool get _isImage => _localPath != null && _isImagePath(_localPath!);

  static bool _isPdfHint(String value) {
    final lower = value.toLowerCase();
    return lower.contains('.pdf') || lower.endsWith('pdf');
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

  static bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
  }

  static bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 3) return false;
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WEBP (RIFF....WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFile);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _localPath = null;
      _pdfController?.dispose();
      _pdfController = null;
    });

    final resolved = resolveEmployeeDrawingFileUrl(widget.fileUrl);
    if (resolved == null || resolved.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'No attachment file is available.';
      });
      return;
    }

    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final localPath = await api.downloadDrawingForLocalEdit(resolved);
      if (!mounted) return;

      final file = File(localPath);
      if (!file.existsSync()) {
        throw StateError('Downloaded attachment file was not found.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Downloaded attachment file is empty.');
      }

      final preferPdf =
          _isPdfHint(resolved) || _isPdfPath(localPath) || _looksLikePdf(bytes);
      final preferImage = _isImagePath(localPath) ||
          _isImagePath(resolved) ||
          _looksLikeImage(bytes);

      if (preferPdf || _looksLikePdf(bytes)) {
        if (!_looksLikePdf(bytes)) {
          throw StateError(
            'This attachment could not be opened as a PDF. The file may be corrupted or inaccessible.',
          );
        }
        // openData avoids Android PdfRenderer "Can't open file" on temp paths.
        final data = Uint8List.fromList(bytes);
        final opened = await PdfDocument.openData(data);
        if (!mounted) {
          await opened.close();
          return;
        }
        setState(() {
          _localPath = localPath;
          _pdfController = PdfControllerPinch(
            document: Future<PdfDocument>.value(opened),
          );
          _loading = false;
        });
        return;
      }

      if (preferImage || _looksLikeImage(bytes)) {
        setState(() {
          _localPath = localPath;
          _loading = false;
        });
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'This file type is not supported for preview.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _friendlyLoadError(error);
      });
    }
  }

  String _friendlyLoadError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains("can't open file") ||
        raw.contains('cant open file') ||
        raw.contains('pdfrendererexception') ||
        raw.contains('invalid pdf')) {
      return 'Could not open this PDF attachment. Please try again, or ask your manager to re-upload the file.';
    }
    return ApiResponseMessage.fromAnyError(
      error,
      genericFallback: 'Could not load attachment file.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfController = _pdfController;
    final localPath = _localPath;
    final heroTag = widget.heroTag?.trim();

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    } else if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadFile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (_isPdf && pdfController != null) {
      body = PdfViewPinch(
        controller: pdfController,
        padding: 10,
        backgroundDecoration: const BoxDecoration(
          color: Color(0xFFF3F4F6),
        ),
      );
    } else if (_isImage && localPath != null) {
      body = ColoredBox(
        color: const Color(0xFFF3F4F6),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.file(
              File(localPath),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not display this image.',
                  textAlign: TextAlign.center,
                  style: AppFonts.bodyMedium(
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      body = const SizedBox.shrink();
    }

    if (heroTag != null && heroTag.isNotEmpty) {
      body = Hero(
        tag: heroTag,
        child: Material(
          type: MaterialType.transparency,
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: body,
    );
  }
}

Future<void> openEmployeeChecklistPdf(
  BuildContext context, {
  required String title,
  required String fileUrl,
  String? heroTag,
}) {
  return context.push(
    EmployeeChecklistPdfPage.path,
    extra: <String, Object?>{
      'title': title,
      'fileUrl': fileUrl,
      if (heroTag != null && heroTag.trim().isNotEmpty) 'heroTag': heroTag.trim(),
    },
  );
}
