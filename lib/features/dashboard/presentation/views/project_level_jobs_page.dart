import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/data/project_jobs_tree_models.dart';
import 'package:red5/features/dashboard/presentation/views/job_details_page.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';

/// Route args for [ProjectLevelJobsPage].
class ProjectLevelJobsArgs {
  const ProjectLevelJobsArgs({
    required this.levelName,
    required this.plots,
    this.projectName,
    this.clientName,
  });

  final String levelName;
  final List<ProjectJobsPlot> plots;
  final String? projectName;
  final String? clientName;

  int get jobCount =>
      plots.fold<int>(0, (count, plot) => count + plot.jobs.length);
}

/// Plot + job list for one level (opened from [ProjectJobsTab]).
class ProjectLevelJobsPage extends StatelessWidget {
  const ProjectLevelJobsPage({
    super.key,
    required this.projectId,
    required this.args,
  });

  static const name = 'project-level-jobs';

  static String pathFor(String projectId) =>
      '${ProjectDetailsPage.pathPrefix}/$projectId/level-jobs';

  final String projectId;
  final ProjectLevelJobsArgs args;

  static final _dateFormat = DateFormat('MMM d, yyyy, h:mm a');

  void _openJob(BuildContext context, ProjectPlotJob job) {
    final end = job.completedAt ?? job.startDate ?? DateTime.now();
    final start = job.startDate ?? end;
    context.push(
      JobDetailsPage.pathFor(projectId, Uri.encodeComponent(job.id.toString())),
      extra: <String, Object?>{
        'jobId': job.id.toString(),
        'jobTitle': job.title,
        'projectName': (args.projectName ?? '').trim(),
        'clientName': (args.clientName ?? '').trim(),
        'workerName': job.assignedWorkerName ?? '',
        'startDate': start.toIso8601String(),
        'scheduleDate': end.toIso8601String(),
        'status': job.isCompleted ? 'Completed' : (job.statusName ?? 'Active'),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final countLabel = args.jobCount == 1 ? '1 job' : '${args.jobCount} jobs';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              args.levelName,
              style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              countLabel,
              style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: args.plots.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final plot = args.plots[index];
          return _PlotJobsSection(
            plot: plot,
            formatDate: (value) =>
                value == null ? '—' : _dateFormat.format(value.toLocal()),
            onJobTap: (job) => _openJob(context, job),
          );
        },
      ),
    );
  }
}

class _PlotJobsSection extends StatelessWidget {
  const _PlotJobsSection({
    required this.plot,
    required this.formatDate,
    required this.onJobTap,
  });

  static const _border = Color(0xFFE5E7EB);

  final ProjectJobsPlot plot;
  final String Function(DateTime?) formatDate;
  final ValueChanged<ProjectPlotJob> onJobTap;

  @override
  Widget build(BuildContext context) {
    final jobCount = plot.jobs.length;
    final countLabel = jobCount == 1 ? '1 job' : '$jobCount jobs';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 20,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      plot.name,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      countLabel,
                      style: AppFonts.labelSmall(
                        color: const Color(0xFF6B7280),
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: _border),
            for (var i = 0; i < plot.jobs.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, thickness: 1, color: _border),
              _JobListTile(
                job: plot.jobs[i],
                formatDate: formatDate,
                onTap: () => onJobTap(plot.jobs[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobListTile extends StatelessWidget {
  const _JobListTile({
    required this.job,
    required this.formatDate,
    required this.onTap,
  });

  final ProjectPlotJob job;
  final String Function(DateTime?) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worker = job.assignedWorkerName?.trim();
    final statusName = job.statusName?.trim();

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.25,
                      ),
                    ),
                    if (worker != null && worker.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        worker,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodySmall(
                          color: const Color(0xFF6B7280),
                        ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Start: ${formatDate(job.startDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF9CA3AF),
                      ).copyWith(fontSize: 13),
                    ),
                    if (job.completedAt != null)
                      Text(
                        'End: ${formatDate(job.completedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodySmall(
                          color: const Color(0xFF9CA3AF),
                        ).copyWith(fontSize: 13),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (statusName != null && statusName.isNotEmpty)
                    _StatusBadge(
                      statusName: statusName,
                      isCompleted: job.isCompleted,
                    )
                  else
                    Text(
                      '—',
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.statusName,
    required this.isCompleted,
  });

  final String statusName;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final completed =
        isCompleted || statusName.toLowerCase().contains('complete');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppFonts.labelSmall(
          color: completed
              ? const Color(0xFF16A34A)
              : const Color(0xFF6B7280),
        ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
