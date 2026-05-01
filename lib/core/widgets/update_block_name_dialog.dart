import 'package:flutter/material.dart';
import 'package:red5/core/widgets/app_button.dart';

/// Returns trimmed block name, or `null` if cancelled.
Future<String?> showBlockNameDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  String? initialValue,
  String confirmLabel = 'Continue',
}) async {
  final result = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _BlockNameDialogBody(
      title: title,
      subtitle: subtitle,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
    ),
  );

  final trimmed = result?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

class _BlockNameDialogBody extends StatefulWidget {
  const _BlockNameDialogBody({
    required this.title,
    required this.subtitle,
    required this.initialValue,
    required this.confirmLabel,
  });

  final String title;
  final String subtitle;
  final String? initialValue;
  final String confirmLabel;

  @override
  State<_BlockNameDialogBody> createState() => _BlockNameDialogBodyState();
}

class _BlockNameDialogBodyState extends State<_BlockNameDialogBody> {
  late final TextEditingController _blockNameController;

  @override
  void initState() {
    super.initState();
    _blockNameController = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _blockNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF111827),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFF9CA3AF),
                    size: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'BLOCK NAME',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF111827), width: 3),
              ),
              child: TextField(
                controller: _blockNameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Block A, Building 1...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    isPrimary: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: widget.confirmLabel,
                    onPressed: () {
                      final t = _blockNameController.text.trim();
                      if (t.isEmpty) return;
                      Navigator.of(context).pop(t);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
