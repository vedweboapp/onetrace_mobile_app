import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_confirmation_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_form_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_safety_verification_page.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_detail_widgets.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_form_picker_sheet.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/jobs/data/job_completion_debug_log.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/jobs/application/employee_qr_scan_flow.dart';
import 'package:red5/employee_role/jobs/application/job_form_submission_sync_listener.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_timer_banner.dart';

class EmployeeJobDetailsPage extends ConsumerStatefulWidget {
  const EmployeeJobDetailsPage({super.key, this.jobId});

  static const path = '/employee-role/jobs/detail';
  static const name = 'employee-job-detail';

  final int? jobId;

  @override
  ConsumerState<EmployeeJobDetailsPage> createState() =>
      _EmployeeJobDetailsPageState();
}

class _EmployeeJobDetailsPageState
    extends ConsumerState<EmployeeJobDetailsPage> {
  bool _safetyRedirectChecked = false;
  bool _timerSynced = false;
  bool _isSubmittingForms = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(employeeJobDetailControllerProvider.notifier)
          .load(jobId: widget.jobId);
      _syncJobTimerWithLoadedJob();
    });
  }

  void _syncJobTimerWithLoadedJob() {
    if (_timerSynced) return;
    final jobId = widget.jobId;
    if (jobId == null) return;

    final detailState = ref.read(employeeJobDetailControllerProvider);
    final job = detailState.job;
    final session = ref.read(employeeJobSessionProvider.notifier);

    _timerSynced = true;

    final apiCompleted =
        job != null && _statusFromLabel(job.currentStatus) == EmployeeJobStatus.completed;
    final formsAllowCompletion = detailState.formIds.isEmpty ||
        detailState.allRequiredFormsComplete;

    if (apiCompleted && formsAllowCompletion) {
      session.completeJob(jobId);
      return;
    }

    if (apiCompleted && !formsAllowCompletion) {
      session.reopenJob(jobId);
    }

    if (session.isJobStarted(jobId)) {
      session.ensureJobSessionHydrated(jobId);
    }
  }

  void _redirectToSafetyIfNeeded(EmployeeJobDetailState state) {
    if (_safetyRedirectChecked || widget.jobId == null) return;
    final job = state.job;
    if (job == null || state.isLoading) return;

    _safetyRedirectChecked = true;
    final session = ref.read(employeeJobSessionProvider.notifier);
    final needsSafety = session.needsSafetyVerification(
      jobId: widget.jobId!,
      status: _statusFromLabel(job.currentStatus),
    );
    final hasChecklist = job.safetyChecklist.isNotEmpty;
    if (!needsSafety || !hasChecklist) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pushReplacement(
        EmployeeJobSafetyVerificationPage.path,
        extra: <String, Object?>{'jobId': widget.jobId},
      );
    });
  }

  EmployeeJobStatus _statusFromLabel(String label) {
    final normalized = label.trim().toUpperCase();
    if (normalized.contains('PROGRESS')) return EmployeeJobStatus.inProgress;
    if (normalized.contains('COMPLETE')) return EmployeeJobStatus.completed;
    if (normalized.contains('TO DO') || normalized.contains('TODO')) {
      return EmployeeJobStatus.upcoming;
    }
    if (normalized.contains('PENDING')) return EmployeeJobStatus.pending;
    return EmployeeJobStatus.upcoming;
  }

  Future<void> _scanQrCode() async {
    final jobId = ref.read(employeeJobDetailControllerProvider).job?.id ??
        widget.jobId;
    final success = await runEmployeeQrScanFlow(
      context,
      ref,
      jobId: jobId,
    );
    if (!mounted || !success) return;
    ref.read(employeeJobDetailControllerProvider.notifier).markQrCodeScanned();
  }

  void _onRequiredFormItemTap(String itemId) {
    switch (itemId) {
      case 'linked_forms':
        _openFormPicker();
      case 'safety_checklist':
        _openSafetyChecklist();
      case 'qr_scan':
        _scanQrCode();
      default:
        break;
    }
  }

  Future<void> _openSafetyChecklist() async {
    final jobId = ref.read(employeeJobDetailControllerProvider).job?.id ??
        widget.jobId;
    if (jobId == null) return;
    await context.push(
      EmployeeJobSafetyVerificationPage.path,
      extra: <String, Object?>{'jobId': jobId},
    );
    if (!mounted) return;
    await ref
        .read(employeeJobDetailControllerProvider.notifier)
        .load(jobId: jobId);
  }

  Future<void> _openFormPicker() async {
    final controller = ref.read(employeeJobDetailControllerProvider.notifier);
    await controller.refreshAttachedForms();

    if (!mounted) return;
    final state = ref.read(employeeJobDetailControllerProvider);
    final isCompletedJob = controller.isJobCompleted;
    final selected = await showEmployeeJobFormPickerSheet(
      context: context,
      selectedFormId: state.selectedFormId,
      allowCompletedSelection: true,
      subtitle: isCompletedJob
          ? 'Tap a submitted form to review or update it.'
          : 'Tap a form to fill it in or update a submitted one.',
      forms: [
        for (final formId in state.formIds)
          EmployeeJobFormOption(
            formId: formId,
            title: state.titleForForm(formId),
            isComplete: state.completedFormIds.contains(formId),
          ),
      ],
    );
    if (selected == null || !mounted) return;
    final activeJobId = state.job?.id ?? widget.jobId;
    var jobFormId = controller.jobFormIdFor(selected);
    if ((jobFormId == null || jobFormId <= 0) && activeJobId != null) {
      jobFormId = await ref
          .read(jobFormSubmissionRepositoryProvider)
          .resolveJobFormId(
            jobId: activeJobId,
            formTemplateId: selected,
            assignments: state.job?.formAssignments ?? const [],
          );
    }
    final submissionId = controller.submissionIdFor(selected);
    final submitted = await context.push<bool>(
      EmployeeJobFormPage.path,
      extra: <String, Object?>{
        'formId': selected,
        'jobId': activeJobId,
        if (jobFormId != null && jobFormId > 0) 'jobFormId': jobFormId,
        if (submissionId != null) 'submissionId': submissionId,
      },
    );
    if (!mounted || submitted != true) return;
    await ref
        .read(employeeJobDetailControllerProvider.notifier)
        .refreshCompletedForms();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeJobDetailControllerProvider);
    final controller = ref.read(employeeJobDetailControllerProvider.notifier);
    final session = ref.watch(employeeJobSessionProvider);
    final sessionController = ref.read(employeeJobSessionProvider.notifier);
    final job = state.job;

    _redirectToSafetyIfNeeded(state);

    final dynamicFormComplete = state.allRequiredFormsComplete;

    final canSubmit = controller.canSubmit(
      dynamicFormComplete: dynamicFormComplete,
    );

    final statusLabel = controller.liveStatusLabel(
      formsIncomplete:
          job != null && state.formIds.isNotEmpty && !dynamicFormComplete,
    );

    final requiredItems = job == null
        ? const <EmployeeRequiredFormItem>[]
        : buildEmployeeRequiredFormItems(
            job: job,
            formIds: state.formIds,
            completedFormIds: state.completedFormIds,
            hasQrScan: state.qrCodeScanned,
            dynamicFormComplete: dynamicFormComplete,
            isJobCompleted: controller.isJobCompleted,
          );

    final timerElapsed = widget.jobId == null
        ? Duration.zero
        : session.elapsedFor(widget.jobId!);

    return JobFormSubmissionSyncListener(
      child: Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 44,
        leadingWidth: 42,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
        ),
        title: Text(
          job?.title ?? 'Job Details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (widget.jobId != null)
            IconButton(
              tooltip: 'Scan QR code',
              onPressed: _scanQrCode,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
          ? _JobErrorState(
              message: state.errorMessage!,
              onRetry: () => controller.load(jobId: widget.jobId),
            )
          : job == null
          ? const _JobEmptyState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                        if (sessionController.isJobStarted(job.id)) ...[
                        EmployeeJobTimerBanner(elapsed: timerElapsed),
                        const SizedBox(height: 16),
                      ],
                      EmployeeJobStatusCard(
                        status: statusLabel,
                      ),
                      const SizedBox(height: 24),
                      EmployeeJobInfoSection(job: job),
                      const SizedBox(height: 28),
                      EmployeeJobItemsCard(items: job.items),
                      const SizedBox(height: 22),
                      EmployeeJobTabs(
                        selectedTab: state.selectedTab,
                        onChanged: controller.selectTab,
                      ),
                      const SizedBox(height: 18),
                      if (state.selectedTab == EmployeeJobDetailTab.forms) ...[
                        EmployeeRequiredFormChecklist(
                          items: requiredItems,
                          onItemTap: _onRequiredFormItemTap,
                        ),
                      ] else
                        const EmployeeJobLocationPanel(),
                    ],
                  ),
                ),
                if (!controller.isJobCompleted)
                  _SubmitBar(
                    enabled: canSubmit && !_isSubmittingForms,
                    isLoading: _isSubmittingForms,
                    onSubmit: canSubmit
                        ? () async {
                            if (!context.mounted || _isSubmittingForms) {
                              return;
                            }
                            setState(() => _isSubmittingForms = true);
                            try {
                              final isOnline = ref
                                  .read(connectivityServiceProvider)
                                  .isOnline;
                              if (isOnline) {
                                JobCompletionDebugLog.banner(
                                  'Submit Form — POST submit-form from SQLite | jobId=${job.id}',
                                );
                                await ref
                                    .read(jobFormSubmissionRepositoryProvider)
                                    .syncPendingSubmissionsForJob(
                                      jobId: job.id,
                                      assignments: job.formAssignments,
                                    );
                              }
                              if (!context.mounted) return;
                              if (!isOnline) {
                                context.showTopSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Forms saved offline. They will sync when you are back online.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              await context.push(
                                EmployeeJobConfirmationPage.path,
                                extra: <String, Object?>{
                                  'jobId': job.id,
                                  'jobTitle': job.title,
                                },
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              context.showTopSnackBar(
                                SnackBar(
                                  content: Text(
                                    ApiResponseMessage.fromAnyError(
                                      error,
                                      genericFallback:
                                          'Could not submit forms. Please try again.',
                                    ),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSubmittingForms = false);
                              }
                            }
                          }
                        : null,
                  ),
              ],
            ),
    ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.enabled,
    required this.onSubmit,
    this.isLoading = false,
  });

  final bool enabled;
  final bool isLoading;
  final Future<void> Function()? onSubmit;

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
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!enabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Complete all required sections to submit.',
                    textAlign: TextAlign.center,
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: enabled && !isLoading ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.inkStrong,
                    disabledBackgroundColor: const Color(0xFFB8B8BE),
                    foregroundColor: AppColors.white,
                    disabledForegroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
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
                          'Submit Form',
                          style: AppFonts.titleSmall(
                            color: AppColors.white,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobErrorState extends StatelessWidget {
  const _JobErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _JobEmptyState extends StatelessWidget {
  const _JobEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No job details found.',
        style: AppFonts.bodyMedium(color: AppColors.muted),
      ),
    );
  }
}
