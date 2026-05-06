import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Reusable styled date picker dialog for form fields.
Future<DateTime?> showAppDatePickerDialog(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? helpText,
}) {
  final now = DateTime.now();
  final safeFirstDate = firstDate ?? DateTime(now.year - 25, 1, 1);
  final safeLastDate = lastDate ?? DateTime(now.year + 25, 12, 31);
  final safeInitialDate = initialDate == null
      ? now
      : initialDate.isBefore(safeFirstDate)
      ? safeFirstDate
      : initialDate.isAfter(safeLastDate)
      ? safeLastDate
      : initialDate;

  return showDatePicker(
    context: context,
    initialDate: safeInitialDate,
    firstDate: safeFirstDate,
    lastDate: safeLastDate,
    helpText: helpText,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.ink,
            onPrimary: AppColors.white,
            onSurface: AppColors.inkStrong,
            surface: AppColors.white,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: AppColors.white,
            surfaceTintColor: AppColors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            headerHeadlineStyle: AppFonts.headlineSmall(
              color: AppColors.white,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 24),
            headerHelpStyle: AppFonts.labelLarge(
              color: AppColors.white.withValues(alpha: 0.92),
            ).copyWith(fontWeight: FontWeight.w600),
            dayStyle: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              textStyle: AppFonts.labelLarge(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}
