import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// “RED5” wordmark + optional uppercase tagline (login / splash).
class AppBrandedLogoBlock extends StatelessWidget {
  const AppBrandedLogoBlock({
    super.key,
    this.tagline,
    this.titleStyle,
    this.taglineStyle,
  });

  final String? tagline;
  final TextStyle? titleStyle;
  final TextStyle? taglineStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'RED5',
          style:
              titleStyle ??
              AppFonts.displaySmall(color: AppColors.brandPrimary).copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
        ),
        if (tagline != null && tagline!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            tagline!.trim(),
            textAlign: TextAlign.center,
            style:
                taglineStyle ??
                AppFonts.labelSmall(color: AppColors.brown).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.3,
                ),
          ),
        ],
      ],
    );
  }
}
