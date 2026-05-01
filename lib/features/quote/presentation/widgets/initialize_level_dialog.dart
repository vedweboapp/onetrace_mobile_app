import 'package:flutter/material.dart';

/// Returns trimmed level name, or `null` if the dialog was dismissed without continuing.
Future<String?> showInitializeLevelDialog(
  BuildContext context, {
  required String fileName,
}) {
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _InitializeLevelDialogBody(fileName: fileName),
  );
}

class _InitializeLevelDialogBody extends StatefulWidget {
  const _InitializeLevelDialogBody({required this.fileName});

  final String fileName;

  @override
  State<_InitializeLevelDialogBody> createState() =>
      _InitializeLevelDialogBodyState();
}

class _InitializeLevelDialogBodyState
    extends State<_InitializeLevelDialogBody> {
  late final TextEditingController _levelController;

  @override
  void initState() {
    super.initState();
    _levelController = TextEditingController();
    _levelController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _levelController.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _levelController.text.trim();
    if (t.isEmpty) return;
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _levelController.text.trim().isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF111827),
                    size: 24,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Initialize Level',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                widget.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'LEVEL NAME',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _levelController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => canContinue ? _submit() : null,
              decoration: InputDecoration(
                hintText: 'e.g. Level 1, Basement...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF111827),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF111827),
                    width: 2,
                  ),
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: canContinue ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB70011),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Color(0xFF9CA3AF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
