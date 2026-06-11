import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/forms/data/cached_technician_form.dart';

final class DynamicFormView extends StatelessWidget {
  const DynamicFormView({
    super.key,
    required this.bundle,
  });

  final TechnicianFormBundle bundle;

  static final _syncedAtFormat = DateFormat('MMM d, yyyy · h:mm a');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bundle.summary.name,
          style: AppFonts.headlineSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        if (bundle.summary.description?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 6),
          Text(
            bundle.summary.description!.trim(),
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Last synced: ${_syncedAtFormat.format(bundle.fetchedAt)}',
          style: AppFonts.bodySmall(color: AppColors.muted),
        ),
      ],
    );
  }
}

class TechnicianFormOfflineBanner extends StatelessWidget {
  const TechnicianFormOfflineBanner({
    super.key,
    required this.visible,
    this.isSyncing = false,
  });

  final bool visible;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final message = isSyncing
        ? 'Back online — refreshing form…'
        : 'Offline — showing saved form';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF2D38B)),
      ),
      child: Row(
        children: [
          Icon(
            isSyncing ? Icons.sync_rounded : Icons.cloud_off_rounded,
            size: 18,
            color: const Color(0xFF8A6D1D),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppFonts.bodySmall(
                color: const Color(0xFF8A6D1D),
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
