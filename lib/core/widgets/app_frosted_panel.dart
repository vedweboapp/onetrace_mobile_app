import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

/// Frosted white panel (login form, splash hero) — matches login card styling.
class AppFrostedPanel extends StatelessWidget {
  const AppFrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24,
    this.fillAlpha = 0.80,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fillAlpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
