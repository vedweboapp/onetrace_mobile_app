import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brandPrimary),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surfaceElevated,
    );
  }
}
