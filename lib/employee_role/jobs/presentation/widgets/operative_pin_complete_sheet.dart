import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';

/// Bottom sheet shown when a pin's required work is finished.
///
/// Returns `true` to complete the job, `false` to pick another pin, `null` if dismissed.
Future<bool?> showOperativePinCompleteSheet({
  required BuildContext context,
  EmployeeJobDrawingPin? pin,
  int remainingPins = 0,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _OperativePinCompleteSheet(
      pin: pin,
      remainingPins: remainingPins,
    ),
  );
}

class _OperativePinCompleteSheet extends StatelessWidget {
  const _OperativePinCompleteSheet({
    this.pin,
    required this.remainingPins,
  });

  final EmployeeJobDrawingPin? pin;
  final int remainingPins;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final pinLabel = pin?.displayLabel.trim();
    final hasLabel = pinLabel != null && pinLabel.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkStrong.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF0EA56A),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pin complete',
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
                        ),
                        if (hasLabel) ...[
                          const SizedBox(height: 4),
                          Text(
                            pinLabel,
                            style: AppFonts.bodyMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          remainingPins > 0
                              ? '$remainingPins more pin${remainingPins == 1 ? '' : 's'} still need work on this job.'
                              : 'All pins on this job are complete.',
                          style: AppFonts.bodySmall(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 18,
                        color: Color(0xFF0EA56A),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'What would you like to do next?',
                          style: AppFonts.bodySmall(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.inkStrong,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.push_pin_rounded, size: 20),
                  label: Text(
                    remainingPins > 0 ? 'Work on another pin' : 'Back to drawing',
                    style: AppFonts.labelLarge(color: AppColors.white)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inkStrong,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.event_available_rounded, size: 20),
                  label: Text(
                    'Complete job',
                    style: AppFonts.labelLarge(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Stay on this pin',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
