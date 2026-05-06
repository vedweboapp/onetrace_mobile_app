import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.brandPrimary);
    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surfaceElevated,
      fontFamily: AppFonts.fontFamily,
    );
    final textTheme = AppFonts.interTextTheme(base.textTheme);
    final primaryTextTheme = AppFonts.interTextTheme(base.primaryTextTheme);
    final labelForButtons = AppFonts.labelLarge();

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.transparent,
        surfaceTintColor: AppColors.transparent,
        foregroundColor: AppColors.inkStrong,
        titleTextStyle: AppFonts.titleLarge(color: AppColors.inkStrong)
            .copyWith(fontWeight: FontWeight.w800),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(textStyle: labelForButtons),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(textStyle: labelForButtons),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(textStyle: labelForButtons),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: labelForButtons),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedTextStyle:
            AppFonts.labelLarge().copyWith(fontWeight: FontWeight.w800),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: AppFonts.bodySmall(),
        floatingLabelStyle: AppFonts.titleSmall(),
        hintStyle: AppFonts.bodyMedium(color: AppColors.textFieldHint),
        errorStyle: AppFonts.bodySmall(color: AppColors.error),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: AppFonts.titleLarge(color: AppColors.inkStrong),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppFonts.titleMedium(),
        subtitleTextStyle: AppFonts.bodyMedium(color: AppColors.muted),
      ),
    );
  }
}
