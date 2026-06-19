import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/forms/application/technician_form_controller.dart';
import 'package:red5/employee_role/forms/application/technician_form_sync_listener.dart';
import 'package:red5/employee_role/forms/presentation/widgets/dynamic_form_view.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/application/job_form_submission_sync_listener.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/jobs/data/job_qr_scan_repository.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/qr_code_details_sheet.dart';

class EmployeeJobFormPage extends ConsumerStatefulWidget {
  const EmployeeJobFormPage({
    super.key,
    required this.formId,
    this.jobId,
    this.jobFormId,
    this.submissionId,
  });

  static const path = '/employee-role/jobs/form';
  static const name = 'employee-job-form';

  final int formId;
  final int? jobId;
  final int? jobFormId;
  final int? submissionId;

  @override
  ConsumerState<EmployeeJobFormPage> createState() =>
      _EmployeeJobFormPageState();
}

class _EmployeeJobFormPageState extends ConsumerState<EmployeeJobFormPage> {
  final _dynamicFormKey = GlobalKey<DynamicFormViewState>();
  final _remarksController = TextEditingController();
  bool _isSubmitting = false;
  bool _restoredValues = false;
  bool _signatureDrawing = false;
  int? _existingSubmissionId;
  int? _cachedJobFormId;
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadForm);
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _remarksController.dispose();
    super.dispose();
  }

  /// Active job the operative is working on — never the form template id.
  int? get _resolvedJobId {
    final fromJob = ref.read(employeeJobDetailControllerProvider).job?.id;
    if (fromJob != null) return fromJob;
    return widget.jobId;
  }

  Future<int?> _resolveJobFormId(int jobId) async {
    if (_cachedJobFormId != null && _cachedJobFormId! > 0) {
      return _cachedJobFormId;
    }
    if (widget.jobFormId != null && widget.jobFormId! > 0) {
      _cachedJobFormId = widget.jobFormId;
      return widget.jobFormId;
    }

    final fromJob = ref
        .read(employeeJobDetailControllerProvider.notifier)
        .jobFormIdFor(widget.formId);
    if (fromJob != null && fromJob > 0) {
      _cachedJobFormId = fromJob;
      return fromJob;
    }

    final job = ref.read(employeeJobDetailControllerProvider).job;
    final resolved = await ref
        .read(jobFormSubmissionRepositoryProvider)
        .resolveJobFormId(
          jobId: jobId,
          formTemplateId: widget.formId,
          assignments: job?.formAssignments ?? const [],
        );
    if (resolved != null && resolved > 0) {
      _cachedJobFormId = resolved;
    }
    return resolved;
  }

  Future<void> _loadForm() async {
    ref
        .read(employeeJobDetailControllerProvider.notifier)
        .selectForm(widget.formId);
    await ref.read(technicianFormControllerProvider.notifier).load(widget.formId);
    await _resolveExistingSubmissionId();
    final jobId = _resolvedJobId;
    if (jobId != null) {
      await _resolveJobFormId(jobId);
    }
    await _restoreSavedValues();
  }

  Future<void> _resolveExistingSubmissionId() async {
    if (widget.submissionId != null && widget.submissionId! > 0) {
      _existingSubmissionId = widget.submissionId;
      return;
    }

    final fromJob = ref
        .read(employeeJobDetailControllerProvider.notifier)
        .submissionIdFor(widget.formId);
    if (fromJob != null && fromJob > 0) {
      _existingSubmissionId = fromJob;
      return;
    }

    final jobId = _resolvedJobId;
    if (jobId == null) return;

    final resolved = await ref
        .read(jobFormSubmissionRepositoryProvider)
        .resolveSubmissionId(jobId: jobId, formTemplateId: widget.formId);
    if (resolved != null && resolved > 0) {
      _existingSubmissionId = resolved;
    }
  }

  bool get _isUpdatingExistingSubmission =>
      _existingSubmissionId != null && _existingSubmissionId! > 0;

  Future<void> _restoreSavedValues() async {
    if (_restoredValues) return;
    final jobId = _resolvedJobId;
    if (jobId == null) return;

    final repository = ref.read(jobFormSubmissionRepositoryProvider);
    final job = ref.read(employeeJobDetailControllerProvider).job;
    final detailState = ref.read(employeeJobDetailControllerProvider);
    final shouldLoadSubmittedCopy =
        (_existingSubmissionId != null && _existingSubmissionId! > 0) ||
        _jobIsCompleted ||
        detailState.completedFormIds.contains(widget.formId);
    final submission = shouldLoadSubmittedCopy
        ? await repository.loadSubmissionForEdit(
            jobId: jobId,
            formTemplateId: widget.formId,
            submissionId: _existingSubmissionId,
            assignments: job?.formAssignments ?? const [],
          )
        : null;

    final saved = submission?.values ??
        await repository.loadSavedValues(
          jobId: jobId,
          formId: widget.formId,
        );
    final remarks = submission?.remarks ??
        await repository.loadSavedRemarks(
          jobId: jobId,
          formId: widget.formId,
        );
    if (!mounted) return;

    if (remarks != null && remarks.trim().isNotEmpty) {
      _remarksController.text = remarks.trim();
    }
    if (saved != null && saved.isNotEmpty) {
      _dynamicFormKey.currentState?.applyFieldValues(saved);
    }
    _restoredValues = true;
  }

  Future<void> _handleQrCodeScanned(String qrCode) async {
    try {
      final result = await ref.read(jobQrScanRepositoryProvider).processScan(
            qrCode: qrCode,
            jobId: widget.jobId,
          );
      if (!mounted) return;

      await showQrCodeDetailsSheet(
        context,
        details: result.details,
        qrCode: result.qrCode,
      );

      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            result.registeredWithJob
                ? 'QR linked to ${result.details.title}'
                : 'QR details loaded',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              error,
              genericFallback: 'Could not process QR code.',
            ),
          ),
        ),
      );
      rethrow;
    }
  }

  void _scheduleDraftSave() {
    final jobId = _resolvedJobId;
    if (jobId == null) return;

    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 800), () async {
      final formState = _dynamicFormKey.currentState;
      if (formState == null) return;

      final job = ref.read(employeeJobDetailControllerProvider).job;
      final jobFormId = await _resolveJobFormId(jobId);
      final remarksText = _remarksController.text.trim();
      await ref.read(jobFormSubmissionRepositoryProvider).saveDraft(
            jobId: jobId,
            formTemplateId: widget.formId,
            jobFormId: jobFormId,
            values: formState.collectApiValues(),
            remarks: remarksText.isEmpty ? null : remarksText,
            assignments: job?.formAssignments ?? const [],
          );
    });
  }

  Future<void> _saveForm() async {
    final dynamicForm = _dynamicFormKey.currentState;
    if (dynamicForm != null && !dynamicForm.validate()) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    final jobId = _resolvedJobId;
    if (jobId == null) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Job context is missing. Open this form from a job.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final values = dynamicForm?.collectApiValues() ?? const [];
      final remarks = _remarksController.text.trim();
      final job = ref.read(employeeJobDetailControllerProvider).job;
      final jobFormId = await _resolveJobFormId(jobId);
      if (jobFormId == null || jobFormId <= 0) {
        throw StateError(
          'Could not resolve job_form_id for this form. Re-open the job and try again.',
        );
      }
      await ref.read(jobFormSubmissionRepositoryProvider).saveFormLocally(
            jobId: jobId,
            formTemplateId: widget.formId,
            jobFormId: jobFormId,
            values: values,
            status: 'submitted',
            remarks: remarks.isEmpty ? null : remarks,
            submissionId: _existingSubmissionId,
            assignments: job?.formAssignments ?? const [],
          );

      ref
          .read(employeeJobDetailControllerProvider.notifier)
          .markFormComplete(widget.formId);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final message = _isUpdatingExistingSubmission
          ? 'Form updated locally. Tap Submit Form on the job page to sync.'
          : 'Form saved locally. Tap Submit Form on the job page to sync.';

      context.showTopSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              error,
              genericFallback: 'Failed to save form.',
            ),
          ),
        ),
      );
    }
  }

  bool get _jobIsCompleted {
    final jobId = _resolvedJobId;
    if (jobId == null) return false;
    final job = ref.read(employeeJobDetailControllerProvider).job;
    final status = job?.currentStatus.trim().toUpperCase() ?? '';
    if (status.contains('COMPLETE')) return true;
    return ref.read(employeeJobSessionProvider.notifier).isJobCompleted(jobId);
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(technicianFormControllerProvider);
    final jobState = ref.watch(employeeJobDetailControllerProvider);
    final title = jobState.titleForForm(widget.formId);
    final bottom = MediaQuery.paddingOf(context).bottom;

    if (formState.bundle != null && !_restoredValues) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _resolveExistingSubmissionId();
        await _restoreSavedValues();
      });
    }

    return JobFormSubmissionSyncListener(
      child: TechnicianFormSyncListener(
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
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.titleSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.borderLight),
            ),
          ),
          body: formState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : formState.errorMessage != null
                  ? _FormErrorState(
                      message: formState.errorMessage!,
                      onRetry: _loadForm,
                    )
                  : formState.bundle == null
                      ? Center(
                          child: Text(
                            'No form data available.',
                            style: AppFonts.bodyMedium(color: AppColors.muted),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                physics: _signatureDrawing
                                    ? const NeverScrollableScrollPhysics()
                                    : const AlwaysScrollableScrollPhysics(),
                                children: [
                                  TechnicianFormOfflineBanner(
                                    visible: formState.isOfflineCached ||
                                        formState.syncStatus ==
                                            TechnicianFormSyncStatus.syncing,
                                    isSyncing: formState.syncStatus ==
                                        TechnicianFormSyncStatus.syncing,
                                  ),
                                  if (_isUpdatingExistingSubmission || _jobIsCompleted)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        _jobIsCompleted
                                            ? 'This job is completed. You can update this form and save changes.'
                                            : 'You can update this form and save changes.',
                                        style: AppFonts.bodySmall(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  TextField(
                                    controller: _remarksController,
                                    onChanged: (_) => _scheduleDraftSave(),
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      labelText: 'Remarks (optional)',
                                      hintText: 'Add notes about this form',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  DynamicFormView(
                                    key: _dynamicFormKey,
                                    bundle: formState.bundle!,
                                    onChanged: _scheduleDraftSave,
                                    onQrCodeScanned: _handleQrCodeScanned,
                                    onSignatureDrawingChanged: (drawing) {
                                      if (_signatureDrawing == drawing) return;
                                      setState(() => _signatureDrawing = drawing);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding:
                                  EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
                              decoration: const BoxDecoration(
                                color: AppColors.white,
                                border: Border(
                                  top: BorderSide(color: AppColors.borderLight),
                                ),
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton(
                                  onPressed: _isSubmitting ? null : _saveForm,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.inkStrong,
                                    foregroundColor: AppColors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              (_isUpdatingExistingSubmission ||
                                                      _jobIsCompleted)
                                                  ? 'Save Changes'
                                                  : 'Save Form',
                                              style: AppFonts.titleSmall(
                                                color: AppColors.white,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.save_rounded,
                                              size: 18,
                                            ),
                                          ],
                                        ),
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

class _FormErrorState extends StatelessWidget {
  const _FormErrorState({required this.message, required this.onRetry});

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
