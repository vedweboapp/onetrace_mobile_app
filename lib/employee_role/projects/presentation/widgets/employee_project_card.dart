import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';

class EmployeeProjectCard extends StatelessWidget {
  const EmployeeProjectCard({
    super.key,
    required this.project,
    required this.onTap,
  });

  final EmployeeProjectSummary project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = project.isCompleted;
    final statusStyle = _statusStyle(completed);
    final dateLabel = completed
        ? 'Done: ${project.dueDate}'
        : 'Due: ${project.dueDate}';

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.titleLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      project.status.toUpperCase(),
                      style: AppFonts.labelSmall(
                        color: statusStyle.foreground,
                      ).copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dateLabel,
                    style: AppFonts.bodySmall(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Client: ${project.client}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Site: ${project.site}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.inkStrong,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _ProjectStatusStyle _statusStyle(bool completed) {
    if (completed) {
      return const _ProjectStatusStyle(
        background: Color(0xFFF2F3F5),
        foreground: Color(0xFF8B939E),
      );
    }
    return const _ProjectStatusStyle(
      background: Color(0xFFD1FAE5),
      foreground: Color(0xFF065F46),
    );
  }
}

class _ProjectStatusStyle {
  const _ProjectStatusStyle({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
