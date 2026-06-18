import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

final class EmployeeJobFormOption {
  const EmployeeJobFormOption({
    required this.formId,
    required this.title,
    required this.isComplete,
  });

  final int formId;
  final String title;
  final bool isComplete;
}

Future<int?> showEmployeeJobFormPickerSheet({
  required BuildContext context,
  required List<EmployeeJobFormOption> forms,
  int? selectedFormId,
  String? subtitle,
  bool allowCompletedSelection = false,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                'Select Form',
                style: AppFonts.titleLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle ??
                    'Complete every linked form before submitting.',
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              for (final form in forms) ...[
                Material(
                  color: AppColors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(form.formId),
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: selectedFormId == form.formId
                            ? AppColors.surfaceHigh
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedFormId == form.formId
                              ? AppColors.inkStrong
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  form.title,
                                  style: AppFonts.bodyMedium(
                                    color: AppColors.inkStrong,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Form #${form.formId}',
                                  style: AppFonts.bodySmall(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: form.isComplete
                                  ? const Color(0xFFE9FFF5)
                                  : AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              form.isComplete
                                  ? (allowCompletedSelection
                                      ? 'Submitted'
                                      : 'Complete')
                                  : 'Pending',
                              style: AppFonts.labelSmall(
                                color: form.isComplete
                                    ? const Color(0xFF00A86B)
                                    : AppColors.muted,
                              ).copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );
    },
  );
}
