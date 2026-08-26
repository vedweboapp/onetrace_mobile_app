import 'dart:async';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/forms/data/form_video_recorder_constraints.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_video_recorder_page.dart';
import 'package:video_player/video_player.dart';

class FormVideoRecorderField extends StatefulWidget {
  const FormVideoRecorderField({
    super.key,
    required this.label,
    required this.hint,
    required this.readOnly,
    required this.required,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final bool readOnly;
  final bool required;
  final FormPickedVideoValue? value;
  final ValueChanged<FormPickedVideoValue?> onChanged;
  final String? Function(FormPickedVideoValue? value)? validator;

  @override
  State<FormVideoRecorderField> createState() => _FormVideoRecorderFieldState();
}

class _FormVideoRecorderFieldState extends State<FormVideoRecorderField> {
  VideoPlayerController? _previewController;

  @override
  void initState() {
    super.initState();
    _loadPreview(widget.value);
  }

  @override
  void didUpdateWidget(covariant FormVideoRecorderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value?.path != widget.value?.path) {
      _loadPreview(widget.value);
    }
  }

  Future<void> _loadPreview(FormPickedVideoValue? value) async {
    await _previewController?.dispose();
    _previewController = null;
    final path = value?.path.trim();
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      if (mounted) setState(() {});
      return;
    }

    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    controller.setLooping(true);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _previewController = controller);
  }

  Future<void> _record() async {
    if (widget.readOnly) return;
    final recorded = await FormVideoRecorderPage.open(context);
    if (!mounted || recorded == null) return;

    final validationError = FormVideoRecorderConstraints.validate(
      duration: recorded.duration,
      bytes: recorded.sizeBytes,
    );
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    widget.onChanged(recorded);
    await _loadPreview(recorded);
  }

  void _remove() {
    widget.onChanged(null);
    unawaited(_loadPreview(null));
  }

  @override
  void dispose() {
    unawaited(_previewController?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picked = widget.value;
    final preview = _previewController;

    return FormField<FormPickedVideoValue>(
      initialValue: picked,
      validator: (_) => widget.validator?.call(picked),
      builder: (state) {
        final borderColor =
            state.hasError ? AppColors.error : AppColors.border;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DottedBorder(
              options: RoundedRectDottedBorderOptions(
                color: borderColor,
                strokeWidth: 1.2,
                dashPattern: const [5, 4],
                radius: const Radius.circular(12),
                padding: EdgeInsets.zero,
              ),
              child: InkWell(
                onTap: widget.readOnly ? null : _record,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  height: picked == null ? 148 : 196,
                  child: picked == null
                      ? _VideoRecorderPlaceholder(hint: widget.hint)
                      : _VideoRecorderPreview(
                          picked: picked,
                          previewController: preview,
                          readOnly: widget.readOnly,
                          onRemove: _remove,
                          onRetake: _record,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                FormVideoRecorderConstraints.limitsHint,
                style: AppFonts.bodySmall(color: AppColors.muted),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  state.errorText!,
                  style: AppFonts.bodySmall(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VideoRecorderPlaceholder extends StatelessWidget {
  const _VideoRecorderPlaceholder({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.videocam_outlined,
                size: 26,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to record',
              style: AppFonts.bodySmall(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoRecorderPreview extends StatelessWidget {
  const _VideoRecorderPreview({
    required this.picked,
    required this.previewController,
    required this.readOnly,
    required this.onRemove,
    required this.onRetake,
  });

  final FormPickedVideoValue picked;
  final VideoPlayerController? previewController;
  final bool readOnly;
  final VoidCallback onRemove;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final preview = previewController;
    final isReady = preview != null && preview.value.isInitialized;
    final hasLocalFile = picked.path.trim().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasLocalFile && isReady)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: preview.value.size.width,
                height: preview.value.size.height,
                child: VideoPlayer(preview),
              ),
            ),
          )
        else if (hasLocalFile)
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 36,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 8),
                Text(
                  'Video saved',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
              ],
            ),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        picked.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodySmall(color: AppColors.white)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${FormVideoRecorderConstraints.formatDuration(picked.duration)} · '
                        '${FormVideoRecorderConstraints.formatSize(picked.sizeBytes)}',
                        style: AppFonts.labelSmall(color: AppColors.white),
                      ),
                    ],
                  ),
                ),
                if (!readOnly) ...[
                  IconButton(
                    onPressed: onRetake,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
