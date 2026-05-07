import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

class UploadDrawingPage extends ConsumerStatefulWidget {
  const UploadDrawingPage({super.key, required this.projectId});

  static const path = '/upload-drawing';
  static const name = 'upload-drawing';
  final String projectId;

  /// Per-file upload cap (shown in UI; enforced on submit when size is known).
  static const int maxBytesPerFile = 50 * 1024 * 1024;

  @override
  ConsumerState<UploadDrawingPage> createState() => _UploadDrawingPageState();
}

class _UploadDrawingPageState extends ConsumerState<UploadDrawingPage> {
  final List<_DrawingUploadRow> _rows = <_DrawingUploadRow>[];
  bool _isUploading = false;

  static const Set<String> _pdfExtensions = {'pdf'};

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var v = bytes.toDouble();
    var u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    if (u == 0) return '${bytes.toInt()} ${units[u]}';
    return '${v.toStringAsFixed(u == 1 ? 1 : 2)} ${units[u]}';
  }

  Future<void> _selectFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _pdfExtensions.toList(),
      allowMultiple: true,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final existingPaths = _rows.map((r) => r.path).toSet();
    final added = <_DrawingUploadRow>[];
    final tooLarge = <String>[];

    for (final picked in result.files) {
      final path = picked.path;
      if (path == null || path.trim().isEmpty) continue;
      final trimmed = path.trim();
      if (existingPaths.contains(trimmed)) continue;

      final size = picked.size;
      if (size > 0 && size > UploadDrawingPage.maxBytesPerFile) {
        tooLarge.add(picked.name);
        continue;
      }

      final fileName =
          picked.name.trim().isEmpty ? 'document.pdf' : picked.name.trim();
      final int? byteSize = size > 0 ? size : null;

      final row = _DrawingUploadRow(
        path: trimmed,
        originalFileName: fileName,
        sizeBytes: byteSize,
      );
      added.add(row);
      existingPaths.add(trimmed);
    }

    if (!mounted) return;

    if (tooLarge.isNotEmpty) {
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            tooLarge.length == 1
                ? '${tooLarge.first} exceeds 50MB'
                : '${tooLarge.length} files exceed 50MB',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (added.isEmpty) {
      if (tooLarge.isEmpty) {
        context.showTopSnackBar(
          const SnackBar(
            content: Text('No new PDF files could be added'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _rows.addAll(added));
  }

  void _removeRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    if (_isUploading) return;
    final projectId = widget.projectId.trim();
    if (projectId.isEmpty || _rows.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Please add at least one PDF file'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    for (final row in _rows) {
      if (row.nameController.text.trim().isEmpty) {
        context.showTopSnackBar(
          const SnackBar(
            content: Text('Enter a name for each drawing'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    for (final row in _rows) {
      if (row.sizeBytes != null &&
          row.sizeBytes! > UploadDrawingPage.maxBytesPerFile) {
        context.showTopSnackBar(
          SnackBar(
            content: Text(
              '${row.originalFileName} exceeds the 50MB limit',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isUploading = true);
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final uploaded = <Map<String, String>>[];
      for (final row in _rows) {
        final levelName = row.nameController.text.trim();
        final levelResult = await api.upsertLevel(
          projectId: projectId,
          levelName: levelName,
          drawingFilePath: row.path,
        );
        uploaded.add(<String, String>{
          'projectId': projectId,
          'levelId': (levelResult.levelId ?? '').trim(),
          'fileName': row.originalFileName,
          'pdfName': levelName,
          'levelName': levelName,
          'filePath': row.path,
        });
      }
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            uploaded.length > 1
                ? '${uploaded.length} drawings uploaded successfully'
                : 'Drawing uploaded successfully',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final payload = <String, dynamic>{
        'projectId': projectId,
        'uploadCount': uploaded.length,
      };
      if (uploaded.length == 1) {
        final u = uploaded.first;
        payload.addAll(<String, String>{
          'levelId': u['levelId'] ?? '',
          'fileName': u['fileName'] ?? '',
          'pdfName': u['pdfName'] ?? '',
          'levelName': u['levelName'] ?? '',
          'filePath': u['filePath'] ?? '',
        });
      }
      Navigator.of(context).pop(payload);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to upload drawing',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Widget _nameLabel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
          children: const [
            TextSpan(text: 'Name '),
            TextSpan(
              text: '*',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileCard(BuildContext context, _DrawingUploadRow row, int index) {
    final sizeLabel = _formatFileSize(row.sizeBytes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD8D8DA)),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFFB3261E),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.originalFileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (sizeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sizeLabel,
                    style: AppFonts.bodySmall(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: AppColors.inkStrong.withValues(alpha: 0.75),
            ),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'remove') _removeRow(index);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.inkStrong.withValues(alpha: 0.08),
          ),
        ),
        foregroundColor: AppColors.inkStrong,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Upload Drawing',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isUploading ? null : _selectFiles,
                    borderRadius: BorderRadius.circular(16),
                    child: DottedBorder(
                      options: RoundedRectDottedBorderOptions(
                        radius: const Radius.circular(16),
                        color: const Color(0xFFCACACC),
                        strokeWidth: 1.4,
                        dashPattern: const [6, 4],
                        padding: const EdgeInsets.all(0),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEAEAEB),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: AppColors.muted,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Upload PDF Drawing',
                              style: AppFonts.titleMedium(
                                color: AppColors.inkStrong,
                              ).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Drag and drop or tap to browse files\n'
                              'from your device.',
                              textAlign: TextAlign.center,
                              style: AppFonts.bodyMedium(
                                color: AppColors.muted,
                              ).copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _isUploading ? null : _selectFiles,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF101114),
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(
                                'Select File',
                                style: AppFonts.labelLarge(
                                  color: AppColors.white,
                            ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                        if (_rows.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ..._rows.take(3).map(
                                (row) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    row.originalFileName,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.bodySmall(
                                      color: AppColors.inkStrong,
                                    ).copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          if (_rows.length > 3)
                            Text(
                              '+${_rows.length - 3} more files',
                              textAlign: TextAlign.center,
                              style: AppFonts.bodySmall(
                                color: AppColors.muted,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                        ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'MAXIMUM FILE SIZE: 50MB',
                  style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 12,
                  ),
                ),
                ...List<Widget>.generate(_rows.length, (index) {
                  final row = _rows[index];
                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 20 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _nameLabel(),
                        AppTextField(
                          controller: row.nameController,
                          hintText: 'e.g. Floor 01, Podium',
                          fillColor: const Color(0xFFEFEFF0),
                        ),
                        const SizedBox(height: 12),
                        _fileCard(context, row, index),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E2E3))),
              ),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isUploading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E0F12),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: AppFonts.titleMedium(
                                color: AppColors.white,
                              ).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingUploadRow {
  _DrawingUploadRow({
    required this.path,
    required this.originalFileName,
    this.sizeBytes,
  }) : nameController = TextEditingController();

  final String path;
  final String originalFileName;
  final int? sizeBytes;
  final TextEditingController nameController;

  void dispose() => nameController.dispose();
}
