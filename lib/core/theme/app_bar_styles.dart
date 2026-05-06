import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

abstract final class AppBarStyles {
  static AppBar transparent({
    required Widget title,
    List<Widget>? actions,
    bool automaticallyImplyLeading = true,
    Widget? leading,
    double? titleSpacing,
  }) {
    return AppBar(
      backgroundColor: AppColors.transparent,
      surfaceTintColor: AppColors.transparent,
      elevation: 0,
      foregroundColor: AppColors.inkStrong,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      titleSpacing: titleSpacing,
      title: title,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 2,
          color: AppColors.inkStrong.withOpacity(0.1), // swap for any color
        ),
      ),
    );
  }
}
