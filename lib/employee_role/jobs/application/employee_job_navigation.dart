import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_details_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_safety_verification_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_detail_page.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';

void openEmployeeJob(
  BuildContext context, {
  required EmployeeJobSummary job,
}) {
  final container = ProviderScope.containerOf(context);
  final session = container.read(employeeJobSessionProvider.notifier);
  final displayJob = session.withLocalProgress(job);

  final showCompletionSummary =
      displayJob.status == EmployeeJobStatus.completed ||
      displayJob.primaryActionLabel == 'View Details';

  if (showCompletionSummary) {
    context.push(
      EmployeeJobSheetDetailPage.path,
      extra: displayJob,
    );
    return;
  }

  final needsSafety = session.needsSafetyVerification(
    jobId: displayJob.id,
    status: displayJob.status,
  );

  final path = needsSafety
      ? EmployeeJobSafetyVerificationPage.path
      : EmployeeJobDetailsPage.path;

  context.push(path, extra: <String, Object?>{'jobId': displayJob.id});
}

EmployeeJobSummary employeeJobSummaryFromProjectItem(
  EmployeeProjectJobItem job,
) {
  final statusUpper = job.status.toUpperCase();
  final status = switch (statusUpper) {
    _ when statusUpper.contains('PROGRESS') || statusUpper.contains('ACTIVE') =>
      EmployeeJobStatus.inProgress,
    _ when statusUpper.contains('COMPLETE') => EmployeeJobStatus.completed,
    _ when statusUpper.contains('PENDING') => EmployeeJobStatus.pending,
    _ => EmployeeJobStatus.upcoming,
  };

  return EmployeeJobSummary(
    id: job.id,
    title: job.title,
    status: status,
    earning: job.earning,
    location: job.location,
    schedule: job.schedule,
    primaryActionLabel: job.actionLabel,
  );
}

void openEmployeeProjectJob(
  BuildContext context, {
  required EmployeeProjectJobItem job,
}) {
  openEmployeeJob(
    context,
    job: employeeJobSummaryFromProjectItem(job),
  );
}
