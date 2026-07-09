import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Floating menu shown when an operative map pin is selected.
class OperativeMapPinActionCard extends StatelessWidget {
  const OperativeMapPinActionCard({
    super.key,
    required this.onDrawings,
    required this.onShowRoutes,
  });

  final VoidCallback onDrawings;
  final VoidCallback onShowRoutes;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      elevation: 0,
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionRow(
              label: 'Drawings',
              onTap: onDrawings,
              showDivider: true,
            ),
            _ActionRow(
              label: 'Show Routes',
              onTap: onShowRoutes,
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onTap,
    required this.showDivider,
  });

  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: label == 'Drawings' ? const Radius.circular(14) : Radius.zero,
            bottom: !showDivider ? const Radius.circular(14) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: AppFonts.labelLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: AppColors.borderLight),
      ],
    );
  }
}
