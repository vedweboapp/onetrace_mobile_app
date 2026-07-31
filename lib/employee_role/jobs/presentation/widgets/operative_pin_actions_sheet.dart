import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';

enum OperativePinAction { fillForm, scanQr, continueJob }

/// Bottom sheet with pin form + QR actions after checklist (or on Continue Job).
Future<OperativePinAction?> showOperativePinActionsSheet({
  required BuildContext context,
  required EmployeeJobDrawingPin pin,
  required bool isFormComplete,
  required bool isQrComplete,
  required bool showQrAction,
  bool pinComplete = false,
}) {
  return showModalBottomSheet<OperativePinAction>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 16),
              Text(
                pin.displayLabel,
                style: AppFonts.titleMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete the required actions for this pin.',
                style: AppFonts.bodySmall(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              if (pin.hasForm)
                _ActionCard(
                  title: isFormComplete ? 'Edit Form' : 'Fill Required Form',
                  subtitle: isFormComplete
                      ? '${pin.projectFormName ?? 'Linked form'} — tap to update'
                      : pin.projectFormName ?? 'Linked form',
                  isComplete: isFormComplete,
                  onTap: () => Navigator.of(ctx).pop(OperativePinAction.fillForm),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No form assigned to this pin.',
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
                ),
              if (showQrAction) ...[
                const SizedBox(height: 10),
                _ActionCard(
                  title: 'Scan QR',
                  subtitle: pin.hasQrCode
                      ? 'QR ${pin.qrCode}'
                      : 'Scan a QR code to assign to this pin',
                  isComplete: isQrComplete,
                  onTap: () => Navigator.of(ctx).pop(OperativePinAction.scanQr),
                ),
              ],
              if (pinComplete) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(OperativePinAction.continueJob),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkStrong,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: AppFonts.labelLarge(color: AppColors.white)
                          .copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isComplete
                      ? const Color(0xFF0EA56A)
                      : AppColors.transparent,
                  border: Border.all(
                    color: isComplete
                        ? const Color(0xFF0EA56A)
                        : AppColors.border,
                    width: 1.8,
                  ),
                ),
                child: isComplete
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
