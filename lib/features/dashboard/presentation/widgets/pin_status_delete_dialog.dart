import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Result when the user confirms pin status deletion.
class PinStatusDeleteRequest {
  const PinStatusDeleteRequest({required this.moveToStatusId});

  final String moveToStatusId;
}

/// Delete confirmation with required reassignment (matches settings mockup).
Future<PinStatusDeleteRequest?> showPinStatusDeleteDialog({
  required BuildContext context,
  required PinStatusItem item,
  required List<PinStatusItem> allStatuses,
}) {
  final reassignmentTargets = allStatuses
      .where((s) => s.id != item.id)
      .toList(growable: false);

  return showDialog<PinStatusDeleteRequest>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _PinStatusDeleteDialog(
      item: item,
      reassignmentTargets: reassignmentTargets,
    ),
  );
}

class _PinStatusDeleteDialog extends StatefulWidget {
  const _PinStatusDeleteDialog({
    required this.item,
    required this.reassignmentTargets,
  });

  final PinStatusItem item;
  final List<PinStatusItem> reassignmentTargets;

  @override
  State<_PinStatusDeleteDialog> createState() => _PinStatusDeleteDialogState();
}

class _PinStatusDeleteDialogState extends State<_PinStatusDeleteDialog> {
  String? _moveToId;
  String? _errorText;

  void _confirmDelete() {
    if (widget.reassignmentTargets.isEmpty) {
      setState(() {
        _errorText =
            'Add another status before deleting this one, or reassign pins first.';
      });
      return;
    }
    if (_moveToId == null || _moveToId!.isEmpty) {
      setState(() => _errorText = 'Please select a status to move pins to');
      return;
    }
    Navigator.pop(context, PinStatusDeleteRequest(moveToStatusId: _moveToId!));
  }

  @override
  Widget build(BuildContext context) {
    final dotColor =
        parseHexColor(widget.item.bgColour) ?? AppColors.plotPinBlue;
    final pinLabel = widget.item.pinCount == 1
        ? '1 PIN AFFECTED'
        : '${widget.item.pinCount} PINS AFFECTED';

    return Dialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Status',
              textAlign: TextAlign.center,
              style: AppFonts.titleMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              'Are you sure you want to delete this Status ? This action cannot '
              'be undone and may affect existing pin using this Status. Before '
              'deleting, move records to another status',
              textAlign: TextAlign.center,
              style: AppFonts.bodySmall(
                color: const Color(0xFF6B7280),
              ).copyWith(height: 1.45, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'status : ${widget.item.statusName}',
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    pinLabel,
                    style: AppFonts.labelSmall(color: const Color(0xFF9CA3AF))
                        .copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  style: AppFonts.bodySmall(
                    color: const Color(0xFF6B7280),
                  ).copyWith(fontWeight: FontWeight.w600),
                  children: [
                    const TextSpan(text: 'Move to '),
                    TextSpan(
                      text: '*',
                      style: AppFonts.bodySmall(
                        color: const Color(0xFFDC2626),
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.inkStrong,
                    width: 1.5,
                  ),
                ),
                errorText: _errorText,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _moveToId,
                  isExpanded: true,
                  hint: Text(
                    'Select status',
                    style: AppFonts.bodyMedium(color: AppColors.textFieldHint),
                  ),
                  items: [
                    for (final target in widget.reassignmentTargets)
                      DropdownMenuItem<String>(
                        value: target.id,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    parseHexColor(target.bgColour) ??
                                    AppColors.plotPinBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                target.statusName,
                                style: AppFonts.bodyMedium(
                                  color: AppColors.inkStrong,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: widget.reassignmentTargets.isEmpty
                      ? null
                      : (value) => setState(() {
                          _moveToId = value;
                          _errorText = null;
                        }),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _confirmDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.inkStrong,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Delete',
                  style: AppFonts.bodyLarge(
                    color: AppColors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.inkStrong,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
