import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/employee_home/employee_home_page.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_jobs_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/data/job_completion_debug_log.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/jobs/data/job_pin_completion.dart';
import 'package:red5/employee_role/projects/application/employee_projects_controller.dart';

class EmployeeJobConfirmationPage extends ConsumerStatefulWidget {
  const EmployeeJobConfirmationPage({super.key, this.jobId, this.jobTitle});

  static const path = '/employee-role/jobs/confirmation';
  static const name = 'employee-job-confirmation';

  final int? jobId;
  final String? jobTitle;

  @override
  ConsumerState<EmployeeJobConfirmationPage> createState() =>
      _EmployeeJobConfirmationPageState();
}

class _EmployeeJobConfirmationPageState
    extends ConsumerState<EmployeeJobConfirmationPage> {
  bool _isCompleting = false;

  Future<void> _completeJob() async {
    final activeJobId = widget.jobId;
    if (activeJobId == null || _isCompleting) return;

    setState(() => _isCompleting = true);
    try {
      JobCompletionDebugLog.banner('Complete job started | jobId=$activeJobId');
      final isOnline = ref.read(connectivityServiceProvider).isOnline;

      if (isOnline) {
        JobCompletionDebugLog.step('Step 1/2 — Reload job (GET /jobs/$activeJobId/)');
        await ref
            .read(employeeJobDetailControllerProvider.notifier)
            .load(jobId: activeJobId);
        final detailState = ref.read(employeeJobDetailControllerProvider);
        final job = detailState.job;
        final localPinKeys = job == null
            ? const <String>{}
            : pinFormKeysFromLocalSubmissions(
                levels: job.levels,
                rows: await ref
                    .read(jobFormSubmissionRepositoryProvider)
                    .listLocalSubmissionsForJob(activeJobId),
              );
        final mergedKeys = <String>{
          ...detailState.completedPinFormKeys,
          ...localPinKeys,
        };
        if (job != null) {
          await ref
              .read(employeeJobRepositoryProvider)
              .markReadyPinsCompleteStatus(
                jobId: activeJobId,
                levels: job.levels,
                completedPinFormKeys: mergedKeys,
                scannedPinQrKeys: detailState.scannedPinQrKeys,
              );
          await ref
              .read(employeeJobDetailControllerProvider.notifier)
              .load(jobId: activeJobId);
        }
        final afterState = ref.read(employeeJobDetailControllerProvider);
        final afterJob = afterState.job;
        final incompletePins = afterJob == null
            ? 0
            : countIncompleteAssignedPins(afterJob.levels);
        if (incompletePins > 0) {
          throw StateError(
            incompletePins == 1
                ? 'Complete the remaining pin status before finishing this job.'
                : 'Complete all $incompletePins pin statuses before finishing this job.',
          );
        }
        JobCompletionDebugLog.info(
          'formAssignments: ${afterJob?.formAssignments.map((a) => 'form=${a.formId}→job_form=${a.jobFormId}').join(', ') ?? 'none'}',
        );
      }

      JobCompletionDebugLog.step('Step 2/2 — Mark job completed (PATCH /jobs/$activeJobId/)');
      final detailState = ref.read(employeeJobDetailControllerProvider);
      final completedJob = await ref
          .read(employeeJobRepositoryProvider)
          .markJobCompleted(
            activeJobId,
            completedPinFormKeys: detailState.completedPinFormKeys,
          );
      JobCompletionDebugLog.info(
        'completed_at=${completedJob.completedAt?.toIso8601String() ?? 'n/a'} | status=${completedJob.displayStatus}',
      );

      JobCompletionDebugLog.info('Refresh local job list');
      ref.read(employeeJobSessionProvider.notifier).completeJob(activeJobId);
      if (isOnline) {
        await ref
            .read(employeeJobsControllerProvider.notifier)
            .load(force: true);
        await ref
            .read(employeeProjectsControllerProvider.notifier)
            .load(force: true);
        await ref
            .read(employeeJobDetailControllerProvider.notifier)
            .load(jobId: activeJobId);
      }

      JobCompletionDebugLog.banner('Complete job finished successfully');
      if (!mounted) return;
      TechnicianHomePage.go(context, tab: EmployeeShellTab.home);
      if (!isOnline) {
        tryShowAppTopToast(
          title: 'Job successfully completed',
          subtitle: 'Changes will sync when you are back online.',
          type: AppTopToastType.info,
        );
      } else {
        tryShowSuccessTopPopup(title: 'Job successfully completed');
      }
    } catch (e) {
      if (!mounted) return;
      JobCompletionDebugLog.api(
        label: 'Complete job FAILED',
        method: '—',
        url: 'jobId=$activeJobId',
        error: e,
      );
      setState(() => _isCompleting = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not complete job. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 52,
        leadingWidth: 46,
        titleSpacing: 0,
        leading: const Icon(Icons.groups_rounded, size: 21),
        title: Text(
          'Confirmation',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
              children: const [
                SizedBox(height: 4),
                _SuccessMark(),
                SizedBox(height: 22),
                _StatusPill(),
                SizedBox(height: 18),
                _SuccessCopy(),
                SizedBox(height: 28),
                _ReadyPill(),
                SizedBox(height: 42),
                _ConfirmationActivityCard(
                  icon: Icons.access_time_filled_rounded,
                  title: 'Timesheet updated',
                  subtitle: 'Hours logged automatically',
                ),
                SizedBox(height: 14),
                _ConfirmationActivityCard(
                  icon: Icons.wallet_rounded,
                  title: 'Earning added',
                  subtitle: 'Updated in your Job Sheet',
                ),
              ],
            ),
          ),
          _CompleteJobBar(
            isLoading: _isCompleting,
            onPressed: _isCompleting ? null : _completeJob,
          ),
        ],
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.inkStrong,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.inkStrong.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          color: AppColors.white,
          size: 42,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0ECFF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'COMPLETE JOB',
          style: AppFonts.labelSmall(color: const Color(0xFF4F46E5)).copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _SuccessCopy extends StatelessWidget {
  const _SuccessCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Form submitted\nsuccessfully',
          textAlign: TextAlign.center,
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 24, height: 1.04),
        ),
        const SizedBox(height: 17),
        Text(
          'Your job details and forms have been\nverified. You can now complete the\njob.',
          textAlign: TextAlign.center,
          style: AppFonts.bodyMedium(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w500, height: 1.45),
        ),
      ],
    );
  }
}

class _ReadyPill extends StatelessWidget {
  const _ReadyPill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Ready to complete',
              style: AppFonts.labelMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationActivityCard extends StatelessWidget {
  const _ConfirmationActivityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppColors.muted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.inkStrong,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.white,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteJobBar extends StatelessWidget {
  const _CompleteJobBar({required this.onPressed, this.isLoading = false});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: const Color(0xFFB8B8BE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      'Complete Job',
                      style: AppFonts.titleSmall(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
