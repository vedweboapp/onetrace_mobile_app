import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

class JobSheetStatusChip extends StatelessWidget {
  const JobSheetStatusChip({super.key, required this.status});

  final EmployeeJobStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      EmployeeJobStatus.inProgress => const Color(0xFF5E4BFF),
      EmployeeJobStatus.upcoming => const Color(0xFFE34D1C),
      EmployeeJobStatus.pending => AppColors.muted,
      EmployeeJobStatus.completed => const Color(0xFF0B8F49),
    };
    final background = switch (status) {
      EmployeeJobStatus.inProgress => const Color(0xFFF1EFFF),
      EmployeeJobStatus.upcoming => const Color(0xFFFFF0E8),
      EmployeeJobStatus.pending => AppColors.surfaceHigh,
      EmployeeJobStatus.completed => const Color(0xFFEAF8EF),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: AppFonts.labelSmall(color: color).copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          fontSize: 10,
        ),
      ),
    );
  }
}

class JobSheetJobCard extends StatelessWidget {
  const JobSheetJobCard({
    super.key,
    required this.job,
    required this.onViewDetails,
  });

  final EmployeeJobSummary job;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final highlightEarning = job.status == EmployeeJobStatus.inProgress;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JobSheetStatusChip(status: job.status),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Earning',
                    style: AppFonts.labelSmall(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.earning,
                    style: AppFonts.titleSmall(
                      color: highlightEarning
                          ? const Color(0xFF00A553)
                          : AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            job.title,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 18, height: 1.1),
          ),
          const SizedBox(height: 12),
          _JobSheetMetaRow(icon: Icons.location_on_outlined, label: job.location),
          const SizedBox(height: 6),
          _JobSheetMetaRow(icon: Icons.access_time_rounded, label: job.schedule),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onViewDetails,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                job.primaryActionLabel,
                style: AppFonts.titleSmall(
                  color: AppColors.white,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobSheetMetaRow extends StatelessWidget {
  const _JobSheetMetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppFonts.bodySmall(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
