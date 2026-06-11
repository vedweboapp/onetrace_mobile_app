import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_user_avatar.dart';
import 'package:red5/features/dashboard/data/report_column_fields.dart';
import 'package:red5/features/dashboard/data/report_field_values.dart';
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
  const ReportSummaryListCard({
    super.key,
    required this.item,
    required this.selectedFields,
  });

  final ReportListCardItem item;
  final List<ReportFieldDefinition> selectedFields;

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
    return AppUserAvatar(
      name: item.assigneeName,
      imageUrl: item.assigneeAvatarUrl,
      radius: 14,
      fontSize: 10,
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF)).copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        fontSize: 10,
      ),
    );
  }

  Widget _valueForField(ReportFieldDefinition field) {
    final values = item.allTextValues;
    return switch (field.key) {
      'status' => _statusBadge(item.status),
      'client' || 'created_by' || 'assigned_worker' || 'project_manager' =>
        Row(
          children: [
            _assigneeAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                values[field.key] ?? '—',
                style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      'progress' => Text(
        '${item.progressPercent}%',
        style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      'due_date' => Text(
        _dateFormat.format(item.dueDate),
        style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      'project_name' => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
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
      _ => Text(
          values[field.key] ?? '—',
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
    };
  }

  Widget _statusBadge(ReportSummaryLifecycleStatus status) {
    final colors = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: AppFonts.labelMedium(color: colors.fg).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedFields.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasProjectName = selectedFields.any((f) => f.key == 'project_name');
    final hasStatus = selectedFields.any((f) => f.key == 'status');
    final headerFields = selectedFields
        .where((f) => f.key == 'project_name' || f.key == 'status')
        .toList();
    final bodyFields =
        selectedFields.where((f) => !headerFields.contains(f)).toList();

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
          if (hasProjectName || hasStatus)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasProjectName)
                  Expanded(child: _valueForField(headerFields.firstWhere(
                    (f) => f.key == 'project_name',
                    orElse: () => selectedFields.first,
                  )))
                else
                  const Spacer(),
                if (hasStatus) ...[
                  const SizedBox(width: 8),
                  _statusBadge(item.status),
                ],
              ],
            ),
          for (var i = 0; i < bodyFields.length; i++) ...[
            if (i > 0 || hasProjectName || hasStatus) ...[
              const SizedBox(height: 14),
              if (bodyFields[i].key != 'client' &&
                  bodyFields[i].key != 'progress')
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
              if (bodyFields[i].key != 'client' &&
                  bodyFields[i].key != 'progress')
                const SizedBox(height: 12),
            ],
            if (bodyFields[i].key != 'project_name') ...[
              _fieldLabel(bodyFields[i].label),
              const SizedBox(height: 4),
              _valueForField(bodyFields[i]),
            ],
          ],
        ],
      ),
    );
  }
}
