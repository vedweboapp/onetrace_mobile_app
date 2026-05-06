import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';

/// Shown after committing a box or polygon highlight. Returns trimmed name, or
/// `null` if cancelled.
Future<String?> showNewPlotNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (dialogContext) => const _NewPlotNameDialogBody(),
  );
}

class _NewPlotNameDialogBody extends StatefulWidget {
  const _NewPlotNameDialogBody();

  @override
  State<_NewPlotNameDialogBody> createState() => _NewPlotNameDialogBodyState();
}

class _NewPlotNameDialogBodyState extends State<_NewPlotNameDialogBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _create() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _controller.text.trim().isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Plot Name',
              style: AppFonts.headlineSmall(
                color: AppColors.navInactive,
              ).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Assign a label to this mapped area.',
              style: AppFonts.titleMedium(color: AppColors.muted).copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => canCreate ? _create() : null,
              hintText: 'e.g. Living Room, Plot A...',
              textStyle: AppFonts.titleMedium(
                color: AppColors.textFieldForeground,
              ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppFonts.titleMedium(
                      color: AppColors.muted,
                    ).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: canCreate ? _create : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFB70011),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Color(0xFF9CA3AF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
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
                  child: const Text('Create Plot'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
