import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

class UploadDrawingPage extends ConsumerStatefulWidget {
  const UploadDrawingPage({super.key, required this.projectId});

  static const path = '/upload-drawing';
  static const name = 'upload-drawing';
  final String projectId;

  @override
  ConsumerState<UploadDrawingPage> createState() => _UploadDrawingPageState();
}

class _UploadDrawingPageState extends ConsumerState<UploadDrawingPage> {
  final TextEditingController _pdfNameController = TextEditingController();
  final TextEditingController _levelNameController = TextEditingController();
  final List<_SelectedDrawingFile> _selectedFiles = <_SelectedDrawingFile>[];
  bool _isUploading = false;

  @override
  void dispose() {
    _pdfNameController.dispose();
    _levelNameController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final nextFiles = <_SelectedDrawingFile>[];
    for (final picked in result.files) {
      final path = picked.path;
      if (path == null || path.trim().isEmpty) continue;
      final fileName = picked.name.trim().isEmpty ? 'selected_file' : picked.name;
      nextFiles.add(
        _SelectedDrawingFile(
          name: fileName,
          path: path.trim(),
        ),
      );
    }
    if (nextFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read selected file path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _selectedFiles
        ..clear()
        ..addAll(nextFiles);
      if (_pdfNameController.text.trim().isEmpty) {
        _pdfNameController.text = _selectedFiles.first.name;
      }
    });
  }

  Future<void> _submit() async {
    if (_isUploading) return;
    final projectId = widget.projectId.trim();
    final baseLevelName = _levelNameController.text.trim();
    if (projectId.isEmpty || baseLevelName.isEmpty || _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select file(s) and enter level name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final uploaded = <Map<String, String>>[];
      final hasMultipleFiles = _selectedFiles.length > 1;
      for (var i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        final levelName = hasMultipleFiles
            ? '$baseLevelName ${i + 1}'
            : baseLevelName;
        final levelResult = await api.upsertLevel(
          projectId: projectId,
          levelName: levelName,
          drawingFilePath: file.path,
        );
        uploaded.add(<String, String>{
          'projectId': projectId,
          'levelId': (levelResult.levelId ?? '').trim(),
          'fileName': file.name,
          'pdfName': file.name,
          'levelName': levelName,
          'filePath': file.path,
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploaded.length > 1
                ? '${uploaded.length} drawings uploaded successfully'
                : 'Drawing uploaded successfully',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final first = uploaded.first;
      Navigator.of(context).pop(<String, String>{
        'projectId': first['projectId'] ?? '',
        'levelId': first['levelId'] ?? '',
        'fileName': first['fileName'] ?? '',
        'pdfName': first['pdfName'] ?? '',
        'levelName': first['levelName'] ?? '',
        'filePath': first['filePath'] ?? '',
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        surfaceTintColor: const Color(0xFFF7F7F8),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 2,
            color: AppColors.inkStrong.withOpacity(0.1), // swap for any color
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
                DottedBorder(
                  options: RoundedRectDottedBorderOptions(
                    radius: const Radius.circular(16),
                    color: const Color(0xFFCACACC),
                    strokeWidth: 1.4,
                    dashPattern: const [6, 4],
                    padding: const EdgeInsets.all(0),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
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
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Drag and drop or tap to browse files\nfrom your device',
                          textAlign: TextAlign.center,
                          style: AppFonts.bodyMedium(
                            color: AppColors.muted,
                          ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isUploading ? null : _selectFile,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF101114),
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            'Select File(s)',
                            style: AppFonts.labelLarge(
                              color: AppColors.white,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_selectedFiles.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ..._selectedFiles.take(3).map(
                            (file) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                file.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.bodySmall(
                                  color: AppColors.inkStrong,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          if (_selectedFiles.length > 3)
                            Text(
                              '+${_selectedFiles.length - 3} more files',
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
                const SizedBox(height: 8),
                Text(
                  'MAXIMUM FILE SIZE: 50MB',
                  style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'PDF Name',
                  style: AppFonts.titleMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _pdfNameController,
                  hintText: 'name',
                  fillColor: const Color(0xFFEFEFF0),
                ),
                const SizedBox(height: 16),
                Text(
                  'Level Name',
                  style: AppFonts.titleMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _levelNameController,
                  hintText: 'e.g. Floor 01, Podium',
                  fillColor: const Color(0xFFEFEFF0),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E2E3))),
              ),
              child: SizedBox(
                height: 50,
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
                      : Text(
                          'Continue  →',
                          style: AppFonts.titleMedium(
                            color: AppColors.white,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
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

class _SelectedDrawingFile {
  const _SelectedDrawingFile({
    required this.name,
    required this.path,
  });

  final String name;
  final String path;
}
