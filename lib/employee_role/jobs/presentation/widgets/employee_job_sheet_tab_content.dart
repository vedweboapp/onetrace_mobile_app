import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/employee_role/jobs/application/employee_job_navigation.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_jobs_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_sheet_widgets.dart';

/// Jobs Sheet list — operative bottom-nav Jobs tab.
class EmployeeJobSheetTabContent extends ConsumerWidget {
  const EmployeeJobSheetTabContent({super.key});

  static List<EmployeeJobSummary> sortedJobs(List<EmployeeJobSummary> jobs) {
    final sorted = [...jobs];
    sorted.sort((a, b) {
      final byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
      if (byStatus != 0) return byStatus;

      final aDate = a.startDate;
      final bDate = b.startDate;
      if (aDate == null && bDate == null) return a.id.compareTo(b.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return sorted;
  }

  static int _statusRank(EmployeeJobStatus status) {
    return switch (status) {
      EmployeeJobStatus.inProgress => 0,
      EmployeeJobStatus.upcoming => 1,
      EmployeeJobStatus.pending => 2,
      EmployeeJobStatus.completed => 3,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employeeJobsControllerProvider);
    final controller = ref.read(employeeJobsControllerProvider.notifier);
    final session = ref.read(employeeJobSessionProvider.notifier);
    final jobs = sortedJobs(state.visibleJobsFor(session));

    if (state.isLoading && state.jobs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: AppSkeletonProjectsListBody(
          includeSearchAndFilters: false,
          cardCount: 4,
        ),
      );
    }

    if (state.errorMessage != null && state.jobs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: controller.load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No jobs found.',
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        itemCount: jobs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final job = jobs[index];
          return JobSheetJobCard(
            job: job,
            onViewDetails: () => openEmployeeJob(context, job: job),
          );
        },
      ),
    );
  }
}
