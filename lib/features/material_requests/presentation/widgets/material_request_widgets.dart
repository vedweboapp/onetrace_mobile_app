import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';

class MaterialRequestStatusBadge extends StatelessWidget {
  const MaterialRequestStatusBadge({super.key, required this.status});

  final MaterialRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      MaterialRequestStatus.pending => (
          dot: const Color(0xFF9CA3AF),
          bg: const Color(0xFFF3F4F6),
          fg: const Color(0xFF6B7280),
        ),
      MaterialRequestStatus.partiallyDispatched => (
          dot: const Color(0xFFF97316),
          bg: const Color(0xFFFFF7ED),
          fg: const Color(0xFFC2410C),
        ),
      MaterialRequestStatus.dispatched => (
          dot: const Color(0xFF22C55E),
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF15803D),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: AppFonts.labelMedium(color: colors.fg).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class MaterialRequestSectionTitle extends StatelessWidget {
  const MaterialRequestSectionTitle(this.label, {super.key});

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
