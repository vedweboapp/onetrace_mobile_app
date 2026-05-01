import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

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
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'RED5',
          style:
              titleStyle ??
              theme.textTheme.displaySmall?.copyWith(
                color: AppColors.brandPrimary,
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
                theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.brown,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.3,
                ),
          ),
        ],
      ],
    );
  }
}
