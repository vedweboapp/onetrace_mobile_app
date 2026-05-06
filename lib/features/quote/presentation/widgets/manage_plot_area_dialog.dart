import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';

/// Result of [showManagePlotAreaDialog]. `null` means user dismissed without action.
class PlotManageOutcome {
  const PlotManageOutcome.delete() : delete = true, savedName = null;

  PlotManageOutcome.saved(String raw)
    : delete = false,
      savedName = raw.trim().isEmpty ? null : raw.trim();

  final bool delete;
  final String? savedName;

  bool get isSaved => !delete && savedName != null && savedName!.isNotEmpty;
}

/// Edit plot name, save, or delete plot (and its pins) — for an existing highlight.
Future<PlotManageOutcome?> showManagePlotAreaDialog(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<PlotManageOutcome>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _ManagePlotBody(initialName: initialName),
  );
}

class _ManagePlotBody extends StatefulWidget {
  const _ManagePlotBody({required this.initialName});

  final String initialName;

  @override
  State<_ManagePlotBody> createState() => _ManagePlotBodyState();
}

class _ManagePlotBodyState extends State<_ManagePlotBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    Navigator.of(context).pop(PlotManageOutcome.saved(t));
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plot & pins?'),
        content: const Text(
          'This removes the mapped area and every pin placed in this plot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(const PlotManageOutcome.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Plot',
              style:
                  AppFonts.headlineSmall(color: AppColors.navInactive).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Rename or remove this plot.',
              style: AppFonts.titleMedium(color: AppColors.muted).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => canSave ? _save() : null,
              hintText: 'Plot name',
              textStyle:
                  AppFonts.titleMedium(color: AppColors.textFieldForeground)
                      .copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppFonts.titleMedium(color: AppColors.muted)
                        .copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB70011),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF9CA3AF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppFonts.titleMedium().copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Material(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _confirmDelete,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'Delete Plot & Pins',
                      style: AppFonts.titleMedium(color: AppColors.danger)
                          .copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
