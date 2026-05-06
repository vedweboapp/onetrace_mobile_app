import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isPrimary = true,
    this.height = 56,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? AppColors.brandOnPrimary : AppColors.iconDark;
    final background = isPrimary ? AppColors.brandPrimary : AppColors.surface;

    final baseLabel = AppFonts.labelLarge();
    final style = FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: background.withValues(alpha: 0.6),
      disabledForegroundColor: foreground.withValues(alpha: 0.7),
      minimumSize: Size.fromHeight(height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: baseLabel.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );

    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}
