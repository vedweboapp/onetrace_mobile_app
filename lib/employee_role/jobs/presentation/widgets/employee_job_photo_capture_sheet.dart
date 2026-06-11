import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

final class EmployeeJobPhotoCaptureData {
  const EmployeeJobPhotoCaptureData({
    this.beforeBytes,
    this.beforeName,
    this.afterBytes,
    this.afterName,
  });

  final Uint8List? beforeBytes;
  final String? beforeName;
  final Uint8List? afterBytes;
  final String? afterName;

  bool get isComplete => beforeBytes != null && afterBytes != null;
}

Future<EmployeeJobPhotoCaptureData?> showEmployeeJobPhotoCaptureSheet({
  required BuildContext context,
  Uint8List? beforeBytes,
  String? beforeName,
  Uint8List? afterBytes,
  String? afterName,
}) {
  return showModalBottomSheet<EmployeeJobPhotoCaptureData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return _EmployeeJobPhotoCaptureSheet(
        initialBeforeBytes: beforeBytes,
        initialBeforeName: beforeName,
        initialAfterBytes: afterBytes,
        initialAfterName: afterName,
      );
    },
  );
}

class _EmployeeJobPhotoCaptureSheet extends StatefulWidget {
  const _EmployeeJobPhotoCaptureSheet({
    this.initialBeforeBytes,
    this.initialBeforeName,
    this.initialAfterBytes,
    this.initialAfterName,
  });

  final Uint8List? initialBeforeBytes;
  final String? initialBeforeName;
  final Uint8List? initialAfterBytes;
  final String? initialAfterName;

  @override
  State<_EmployeeJobPhotoCaptureSheet> createState() =>
      _EmployeeJobPhotoCaptureSheetState();
}

class _EmployeeJobPhotoCaptureSheetState
    extends State<_EmployeeJobPhotoCaptureSheet> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _beforeBytes;
  String? _beforeName;
  Uint8List? _afterBytes;
  String? _afterName;
  bool _pickingBefore = false;
  bool _pickingAfter = false;

  @override
  void initState() {
    super.initState();
    _beforeBytes = widget.initialBeforeBytes;
    _beforeName = widget.initialBeforeName;
    _afterBytes = widget.initialAfterBytes;
    _afterName = widget.initialAfterName;
  }

  bool get _isComplete => _beforeBytes != null && _afterBytes != null;

  String _cameraErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission') || message.contains('denied')) {
      return 'Camera permission was denied.';
    }
    if (message.contains('camera')) return 'Could not open camera.';
    return 'Could not capture photo.';
  }

  Future<void> _capture({required bool isBefore}) async {
    if (_pickingBefore || _pickingAfter) return;
    setState(() {
      if (isBefore) {
        _pickingBefore = true;
      } else {
        _pickingAfter = true;
      }
    });

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (!mounted || picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final name = picked.name.trim().isEmpty
          ? (isBefore ? 'before-photo.jpg' : 'after-photo.jpg')
          : picked.name;

      setState(() {
        if (isBefore) {
          _beforeBytes = bytes;
          _beforeName = name;
        } else {
          _afterBytes = bytes;
          _afterName = name;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cameraErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickingBefore = false;
          _pickingAfter = false;
        });
      }
    }
  }

  void _save() {
    Navigator.of(context).pop(
      EmployeeJobPhotoCaptureData(
        beforeBytes: _beforeBytes,
        beforeName: _beforeName,
        afterBytes: _afterBytes,
        afterName: _afterName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Job Photos',
              style: AppFonts.titleLarge(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Capture before and after photos using your device camera.',
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            _PhotoSlot(
              label: 'Before Photo',
              bytes: _beforeBytes,
              fileName: _beforeName,
              isPicking: _pickingBefore,
              onTap: () => _capture(isBefore: true),
            ),
            const SizedBox(height: 14),
            _PhotoSlot(
              label: 'After Photo',
              bytes: _afterBytes,
              fileName: _afterName,
              isPicking: _pickingAfter,
              onTap: () => _capture(isBefore: false),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isComplete ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.inkStrong,
                  disabledBackgroundColor: const Color(0xFFB8B8BE),
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _isComplete ? 'Save Photos' : 'Capture both photos to save',
                  style: AppFonts.titleSmall(
                    color: AppColors.white,
                  ).copyWith(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.bytes,
    required this.fileName,
    required this.isPicking,
    required this.onTap,
  });

  final String label;
  final Uint8List? bytes;
  final String? fileName;
  final bool isPicking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        DottedBorder(
          options: const RoundedRectDottedBorderOptions(
            color: AppColors.border,
            strokeWidth: 1,
            dashPattern: [5, 4],
            radius: Radius.circular(12),
            padding: EdgeInsets.zero,
          ),
          child: InkWell(
            onTap: isPicking ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 130,
              child: bytes == null
                  ? _Placeholder(isPicking: isPicking)
                  : _Preview(
                      bytes: bytes!,
                      fileName: fileName ?? 'photo.jpg',
                      isPicking: isPicking,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.isPicking});

  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isPicking
          ? const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.muted,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to open camera',
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.bytes,
    required this.fileName,
    required this.isPicking,
  });

  final Uint8List bytes;
  final String fileName;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(bytes, fit: BoxFit.cover),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.labelSmall(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    isPicking ? '...' : 'Retake',
                    style: AppFonts.labelSmall(
                      color: AppColors.white,
                    ).copyWith(fontWeight: FontWeight.w800),
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
