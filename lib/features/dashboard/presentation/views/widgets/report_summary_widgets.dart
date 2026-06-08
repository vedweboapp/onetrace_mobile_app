import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/data/report_models.dart';

enum ReportSummaryViewMode { table, list }

class ReportSummaryViewToggle extends StatelessWidget {
  const ReportSummaryViewToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ReportSummaryViewMode mode;
  final ValueChanged<ReportSummaryViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton(
            selected: mode == ReportSummaryViewMode.table,
            icon: Icons.grid_view_rounded,
            onTap: () => onChanged(ReportSummaryViewMode.table),
          ),
          Container(width: 1, height: 28, color: const Color(0xFFE5E7EB)),
          _toggleButton(
            selected: mode == ReportSummaryViewMode.list,
            icon: Icons.view_list_rounded,
            onTap: () => onChanged(ReportSummaryViewMode.list),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFF3F4F6) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 48,
          height: 46,
          child: Icon(
            icon,
            size: 22,
            color: selected ? AppColors.inkStrong : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

class ReportSummaryListCard extends StatelessWidget {
  const ReportSummaryListCard({super.key, required this.item});

  final ReportListCardItem item;

  static final _dateFormat = DateFormat('MMM d, yyyy');

  ({Color bg, Color fg}) _statusColors(ReportSummaryLifecycleStatus status) {
    return switch (status) {
      ReportSummaryLifecycleStatus.active => (
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF15803D),
        ),
      ReportSummaryLifecycleStatus.inactive => (
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
        ),
    };
  }

  Widget _assigneeAvatar() {
    final url = item.assigneeAvatarUrl?.trim();
    final initial = item.assigneeName.trim().isNotEmpty
        ? item.assigneeName.trim()[0].toUpperCase()
        : '?';

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFFE5E7EB),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, _) {},
        child: Text(
          initial,
          style: AppFonts.labelMedium(color: const Color(0xFF6B7280))
              .copyWith(fontWeight: FontWeight.w700, fontSize: 10),
        ),
      );
    }

    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFE5E7EB),
      child: Text(
        initial,
        style: AppFonts.labelMedium(color: const Color(0xFF6B7280))
            .copyWith(fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = _statusColors(item.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: AppFonts.bodyMedium(color: const Color(0xFF6B7280))
                          .copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColors.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status.label,
                  style: AppFonts.labelMedium(color: statusColors.fg).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _assigneeAvatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.assigneeName,
                  style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                      .copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.progressLabel,
                    style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF))
                        .copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.progressPercent}%',
                    style: AppFonts.titleMedium(color: AppColors.inkStrong)
                        .copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          Text(
            item.dueDateLabel,
            style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF)).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dateFormat.format(item.dueDate),
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
