import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Read-only file viewer for operative job checklist attachments (PDF, PNG, JPG, etc.).
class EmployeeChecklistPdfPage extends ConsumerStatefulWidget {
  const EmployeeChecklistPdfPage({
    super.key,
    required this.title,
    required this.fileUrl,
  });

  static const path = '/employee-role/jobs/checklist-pdf';
  static const name = 'employee-checklist-pdf';

  final String title;
  final String fileUrl;

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

  bool get _isPdf =>
      _localPath != null && _isPdfPath(_localPath!) && _pdfController != null;

  bool get _isImage => _localPath != null && _isImagePath(_localPath!);

  static bool _isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

  static bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
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
        _errorMessage = 'No checklist file is available for this item.';
      });
      return;
    }

    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final localPath = await api.downloadDrawingForLocalEdit(resolved);
      if (!mounted) return;

      if (_isPdfPath(localPath)) {
        final document = PdfDocument.openFile(localPath);
        setState(() {
          _localPath = localPath;
          _pdfController = PdfControllerPinch(document: document);
          _loading = false;
        });
        return;
      }

      if (_isImagePath(localPath)) {
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
        _errorMessage = ApiResponseMessage.fromAnyError(
          error,
          genericFallback: 'Could not load checklist file.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdfController = _pdfController;
    final localPath = _localPath;

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
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _errorMessage != null
              ? Center(
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
                )
              : _isPdf && pdfController != null
                  ? PdfViewPinch(
                      controller: pdfController,
                      padding: 10,
                      backgroundDecoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                      ),
                    )
                  : _isImage && localPath != null
                      ? ColoredBox(
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
                        )
                      : const SizedBox.shrink(),
    );
  }
}

Future<void> openEmployeeChecklistPdf(
  BuildContext context, {
  required String title,
  required String fileUrl,
}) {
  return context.push(
    EmployeeChecklistPdfPage.path,
    extra: <String, Object?>{
      'title': title,
      'fileUrl': fileUrl,
    },
  );
}
