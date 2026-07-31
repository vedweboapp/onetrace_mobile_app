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
import 'package:red5/employee_role/forms/presentation/widgets/form_qr_scanner_page.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/application/job_form_submission_sync_listener.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/jobs/data/job_qr_scan_repository.dart';
import 'package:red5/employee_role/jobs/presentation/employee_checklist_pdf_page.dart';
import 'package:red5/core/utils/qr_code_utils.dart';

class EmployeeJobFormPage extends ConsumerStatefulWidget {
  const EmployeeJobFormPage({
    super.key,
    required this.formId,
    this.jobId,
    this.jobFormId,
    this.jobPinId,
    this.pinId,
    this.submissionId,
    this.requiresPinQr,
  });

  static const path = '/employee-role/jobs/form';
  static const name = 'employee-job-form';

  final int formId;
  final int? jobId;
  final int? jobFormId;
  final int? jobPinId;
  final int? pinId;
  final int? submissionId;

  /// When opening from a pin that includes a `qr_code` field in the API.
  /// Null falls back to the resolved pin's [EmployeeJobDrawingPin.qrCodeFieldPresent].
  final bool? requiresPinQr;

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

  bool get _isPinForm => widget.jobPinId != null && widget.jobPinId! > 0;

  int? _pinIdFromJob(EmployeeJobDetail? job) {
    if (widget.pinId != null && widget.pinId! > 0) return widget.pinId;
    if (!_isPinForm || job == null) return null;

    final jobPinId = widget.jobPinId!;
    for (final entry in collectJobPinEntries(job.levels)) {
      final pin = entry.pin;
      if (!pin.hasForm || pin.projectFormId != widget.formId) continue;
      final linkIds = <int>{
        pin.id,
        if (pin.jobPinId != null && pin.jobPinId! > 0) pin.jobPinId!,
        if (pin.resolvedJobFormId != null && pin.resolvedJobFormId! > 0)
          pin.resolvedJobFormId!,
      };
      if (linkIds.contains(jobPinId)) return pin.id;
    }
    return null;
  }

  int? get _resolvedPinId =>
      _pinIdFromJob(ref.read(employeeJobDetailControllerProvider).job);

  EmployeeJobDrawingPin? _pinFromJob(EmployeeJobDetail? job) {
    final pinId = _pinIdFromJob(job);
    if (pinId == null || job == null) return null;
    return findEmployeeJobPinById(job.levels, pinId);
  }

  EmployeeJobDrawingPin? get _resolvedPin =>
      _pinFromJob(ref.read(employeeJobDetailControllerProvider).job);

  String? _pinFormKeyFor(EmployeeJobDrawingPin? pin, int? pinId) {
    if (pin != null) return pin.formKey;
    if (pinId == null) return null;
    return '${pinId}_${widget.formId}';
  }

  String? get _pinFormKey =>
      _pinFormKeyFor(_resolvedPin, _resolvedPinId);

  bool _pinRequiresQrFor(EmployeeJobDrawingPin? pin) {
    if (!_isPinForm) return false;
    if (widget.requiresPinQr != null) return widget.requiresPinQr!;
    return pin?.qrCodeFieldPresent ?? false;
  }

  bool get _pinRequiresQr => _pinRequiresQrFor(_resolvedPin);

  bool _isPinQrCompleteFor(
    EmployeeJobDrawingPin? pin,
    EmployeeJobDetailState detailState,
  ) {
    if (!_pinRequiresQrFor(pin)) return true;
    if (pin?.hasQrCode == true) return true;
    final key = _pinFormKeyFor(pin, _pinIdFromJob(detailState.job));
    if (key == null) return false;
    return detailState.scannedPinQrKeys.contains(key);
  }

  bool get _isPinQrComplete => _isPinQrCompleteFor(
        _resolvedPin,
        ref.read(employeeJobDetailControllerProvider),
      );

  String? _scannedPinQrCodeFor(
    EmployeeJobDrawingPin? pin,
    EmployeeJobDetailState detailState,
  ) {
    final key = _pinFormKeyFor(pin, _pinIdFromJob(detailState.job));
    if (key == null) return null;
    final fromState = detailState.scannedPinQrCodes[key];
    if (fromState != null && fromState.trim().isNotEmpty) {
      return fromState.trim();
    }
    return pin?.qrCode?.trim();
  }

  Future<int?> _resolveJobFormId(int jobId) async {
    if (_isPinForm) return null;
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
    if (jobId != null && !_isPinForm) {
      await _resolveJobFormId(jobId);
    }
    await _restoreSavedValues();
  }

  Future<void> _resolveExistingSubmissionId() async {
    if (widget.submissionId != null && widget.submissionId! > 0) {
      _existingSubmissionId = widget.submissionId;
      return;
    }

    if (_isPinForm) {
      final jobId = _resolvedJobId;
      if (jobId == null) return;

      final resolved = await ref
          .read(jobFormSubmissionRepositoryProvider)
          .resolveSubmissionId(
            jobId: jobId,
            formTemplateId: widget.formId,
            jobPinId: widget.jobPinId,
          );
      if (resolved != null && resolved > 0) {
        _existingSubmissionId = resolved;
      }
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

  bool get _pinFormComplete {
    final pinId = _resolvedPinId;
    if (pinId == null) return false;
    final pinFormKey = '${pinId}_${widget.formId}';
    return ref
        .read(employeeJobDetailControllerProvider)
        .completedPinFormKeys
        .contains(pinFormKey);
  }

  Future<void> _handleQrCodeScanned(String qrCode) async {
    final normalized = QrCodeUtils.normalizeScannedValue(qrCode);
    if (normalized.isEmpty) return;

    try {
      final result = await ref.read(jobQrScanRepositoryProvider).processScan(
            qrCode: normalized,
            jobId: widget.jobId ?? _resolvedJobId,
            jobPinId: widget.jobPinId,
          );
      if (!mounted) return;

      final pinKey = _pinFormKey;
      if (_isPinForm && pinKey != null) {
        ref.read(employeeJobDetailControllerProvider.notifier).markPinQrCodeScanned(
              pinFormKey: pinKey,
              qrCode: result.qrCode,
            );
      }

      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            result.queuedOffline
                ? 'QR scan saved offline. It will sync when you are back online.'
                : _isPinForm
                    ? 'QR ${result.qrCode} linked to this pin.'
                    : result.registeredWithJob
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

  Future<void> _scanPinQrFromForm() async {
    if (!_isPinForm || _isSubmitting) return;
    final code = await openFormQrScanner(context);
    if (!mounted || code == null || code.trim().isEmpty) return;
    try {
      await _handleQrCodeScanned(code);
    } catch (_) {
      // Toast already shown in _handleQrCodeScanned.
    }
  }

  Future<void> _openPinAttachment(EmployeeJobPinAttachment attachment) async {
    final url = attachment.url.trim();
    if (url.isEmpty) return;
    final pinId = _resolvedPinId ?? widget.pinId ?? 0;
    final heroTag =
        'pin-attachment-$pinId-${attachment.id ?? attachment.url.hashCode}';
    await openEmployeeChecklistPdf(
      context,
      title: 'Attachment',
      fileUrl: url,
      heroTag: heroTag,
    );
  }

  Future<void> _restoreSavedValues() async {
    if (_restoredValues) return;
    final jobId = _resolvedJobId;
    if (jobId == null) return;

    final repository = ref.read(jobFormSubmissionRepositoryProvider);
    final job = ref.read(employeeJobDetailControllerProvider).job;
    final detailState = ref.read(employeeJobDetailControllerProvider);
    final pinFormComplete = _pinFormComplete;
    final shouldLoadSubmittedCopy =
        (_existingSubmissionId != null && _existingSubmissionId! > 0) ||
        _jobIsCompleted ||
        (!_isPinForm && detailState.completedFormIds.contains(widget.formId)) ||
        (_isPinForm && pinFormComplete);

    // Pin forms: also restore locally saved drafts when reopening to edit.
    final submission = shouldLoadSubmittedCopy || _isPinForm
        ? await repository.loadSubmissionForEdit(
            jobId: jobId,
            formTemplateId: widget.formId,
            submissionId: _existingSubmissionId,
            jobPinId: widget.jobPinId,
            assignments: job?.formAssignments ?? const [],
          )
        : null;

    final saved = submission?.values ??
        await repository.loadSavedValues(
          jobId: jobId,
          formId: widget.formId,
          jobPinId: widget.jobPinId,
        );
    final remarks = submission?.remarks ??
        await repository.loadSavedRemarks(
          jobId: jobId,
          formId: widget.formId,
          jobPinId: widget.jobPinId,
        );
    if (!mounted) return;

    if (remarks != null && remarks.trim().isNotEmpty) {
      _remarksController.text = remarks.trim();
    }
    if (saved != null && saved.isNotEmpty) {
      _dynamicFormKey.currentState?.applyFieldValues(saved);
    }
    _restoredValues = true;
    if (mounted) setState(() {});
  }

  void _scheduleDraftSave() {
    final jobId = _resolvedJobId;
    if (jobId == null) return;

    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 800), () async {
      final formState = _dynamicFormKey.currentState;
      if (formState == null) return;

      final job = ref.read(employeeJobDetailControllerProvider).job;
      final jobFormId = _isPinForm ? null : await _resolveJobFormId(jobId);
      final remarksText = _remarksController.text.trim();
      await ref.read(jobFormSubmissionRepositoryProvider).saveDraft(
            jobId: jobId,
            formTemplateId: widget.formId,
            jobFormId: jobFormId,
            jobPinId: widget.jobPinId,
            values: await formState.collectApiValuesAsync(),
            remarks: remarksText.isEmpty ? null : remarksText,
            assignments: job?.formAssignments ?? const [],
          );
    });
  }

  Future<void> _submitForm() async {
    final dynamicForm = _dynamicFormKey.currentState;
    if (dynamicForm != null && !dynamicForm.validate()) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    if (_pinRequiresQr && !_isPinQrComplete) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Scan the pin QR code before submitting the form.'),
        ),
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
      final values =
          await dynamicForm?.collectApiValuesAsync() ?? const <JobFormFieldValue>[];
      final remarks = _remarksController.text.trim();
      final job = ref.read(employeeJobDetailControllerProvider).job;
      final jobFormId = _isPinForm ? null : await _resolveJobFormId(jobId);
      if (!_isPinForm && (jobFormId == null || jobFormId <= 0)) {
        throw StateError(
          'Could not resolve job_form_id for this form. Re-open the job and try again.',
        );
      }
      if (_isPinForm && (widget.jobPinId == null || widget.jobPinId! <= 0)) {
        throw StateError(
          'Could not resolve job_pin_id for this pin form. Re-open the job and try again.',
        );
      }

      final repository = ref.read(jobFormSubmissionRepositoryProvider);
      await repository.saveFormLocally(
        jobId: jobId,
        formTemplateId: widget.formId,
        jobFormId: jobFormId,
        jobPinId: widget.jobPinId,
        values: values,
        status: 'submitted',
        remarks: remarks.isEmpty ? null : remarks,
        submissionId: _existingSubmissionId,
        assignments: job?.formAssignments ?? const [],
      );

      final detailController =
          ref.read(employeeJobDetailControllerProvider.notifier);
      detailController.markFormComplete(
        widget.formId,
        pinId: _isPinForm ? _resolvedPinId : null,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      const message =
          'Form saved locally. It will submit when you complete the job.';

      context.showTopSnackBar(
        const SnackBar(
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
    final resolvedPin = _pinFromJob(jobState.job);
    final pinRequiresQr = _pinRequiresQrFor(resolvedPin);
    final pinQrComplete = _isPinQrCompleteFor(resolvedPin, jobState);
    final scannedPinQrCode = _scannedPinQrCodeFor(resolvedPin, jobState);
    final requiredFieldsComplete = _dynamicFormKey.currentState
            ?.areRequiredFieldsComplete(ignoreQrFields: pinRequiresQr) ??
        false;
    final showPinQrSection =
        pinRequiresQr && (requiredFieldsComplete || pinQrComplete);
    final pinAttachments = resolvedPin?.attachments
            .where((attachment) => attachment.hasUrl)
            .toList(growable: false) ??
        const <EmployeeJobPinAttachment>[];

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
                                  if (pinAttachments.isNotEmpty) ...[
                                    for (var i = 0;
                                        i < pinAttachments.length;
                                        i++) ...[
                                      if (i > 0) const SizedBox(height: 10),
                                      _PinOpenAttachmentButton(
                                        pinId: resolvedPin?.id ??
                                            widget.pinId ??
                                            0,
                                        attachment: pinAttachments[i],
                                        onOpen: () => _openPinAttachment(
                                          pinAttachments[i],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                  ],
                                  if (_isUpdatingExistingSubmission ||
                                      _pinFormComplete ||
                                      _jobIsCompleted)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        _jobIsCompleted
                                            ? 'This job is completed. You can update this form and save changes.'
                                            : _isUpdatingExistingSubmission ||
                                                    _pinFormComplete
                                                ? 'You can edit this form and tap Submit Form to save changes.'
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
                                    hideQrFields: pinRequiresQr,
                                    onChanged: () {
                                      _scheduleDraftSave();
                                      setState(() {});
                                    },
                                    onQrCodeScanned: _handleQrCodeScanned,
                                    onSignatureDrawingChanged: (drawing) {
                                      if (_signatureDrawing == drawing) return;
                                      setState(() => _signatureDrawing = drawing);
                                    },
                                  ),
                                  if (showPinQrSection) ...[
                                    const SizedBox(height: 16),
                                    _PinQrScanCard(
                                      isComplete: pinQrComplete,
                                      scannedCode: scannedPinQrCode,
                                      enabled: !_isSubmitting,
                                      onScan: _scanPinQrFromForm,
                                    ),
                                  ],
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
                                  onPressed: _isSubmitting ? null : _submitForm,
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
                                              'Submit Form',
                                              style: AppFonts.titleSmall(
                                                color: AppColors.white,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.send_rounded,
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

class _PinOpenAttachmentButton extends StatelessWidget {
  const _PinOpenAttachmentButton({
    required this.pinId,
    required this.attachment,
    required this.onOpen,
  });

  final int pinId;
  final EmployeeJobPinAttachment attachment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final heroTag =
        'pin-attachment-$pinId-${attachment.id ?? attachment.url.hashCode}';

    return Hero(
      tag: heroTag,
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  size: 20,
                  color: AppColors.inkStrong,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Open Attachment',
                    style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinQrScanCard extends StatelessWidget {
  const _PinQrScanCard({
    required this.isComplete,
    required this.scannedCode,
    required this.enabled,
    required this.onScan,
  });

  final bool isComplete;
  final String? scannedCode;
  final bool enabled;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final code = scannedCode?.trim();
    final hasCode = code != null && code.isNotEmpty;

    // Already scanned: only show the QR code value at the bottom.
    if (isComplete && hasCode) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          code,
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 20,
                color: AppColors.inkStrong,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pin QR code',
                  style: AppFonts.titleSmall(color: AppColors.inkStrong)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Scan the QR code for this pin after completing the required fields.',
            style: AppFonts.bodySmall(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: enabled ? onScan : null,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan QR code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkStrong,
                side: const BorderSide(color: AppColors.borderLight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
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
