import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dispatch/data/dispatch_models.dart';

class DispatchStatusBadge extends StatelessWidget {
  const DispatchStatusBadge({super.key, required this.status});

  final DispatchStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      DispatchStatus.active => (
          fg: const Color(0xFF15803D),
        ),
      DispatchStatus.dispatched => (
          fg: const Color(0xFF2563EB),
        ),
      DispatchStatus.pending => (
          fg: const Color(0xFF6B7280),
        ),
    };

    return Text(
      status.label,
      style: AppFonts.labelMedium(color: colors.fg).copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );
  }
}

class DispatchSectionTitle extends StatelessWidget {
  const DispatchSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
