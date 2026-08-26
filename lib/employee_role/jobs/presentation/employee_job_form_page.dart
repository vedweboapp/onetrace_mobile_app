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
import 'package:red5/employee_role/jobs/application/operative_canvas_bridge.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/jobs/data/job_qr_scan_repository.dart';
import 'package:red5/employee_role/jobs/presentation/employee_checklist_pdf_page.dart';
import 'package:red5/core/utils/qr_code_utils.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

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
  bool _isSubmitting = false;
  bool _restoredValues = false;
  bool _signatureDrawing = false;
  int? _existingSubmissionId;
  int? _cachedJobFormId;
  Timer? _draftSaveTimer;
  List<JobFormFieldValue>? _pendingRestoreValues;
  List<PinStatusItem> _pinStatuses = const [];
  bool _pinStatusesLoading = false;
  bool _pinStatusSaving = false;
  String? _pinStatusError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadForm);
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
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
    // Prefer API `qr_code_id` — never show raw numeric / qr_code ids here.
    final qrCodeId = pin?.displayQrCodeId;
    if (qrCodeId != null && qrCodeId.isNotEmpty) return qrCodeId;

    final key = _pinFormKeyFor(pin, _pinIdFromJob(detailState.job));
    if (key == null) return null;
    final fromState = detailState.scannedPinQrCodes[key]?.trim();
    if (fromState != null && fromState.isNotEmpty) return fromState;
    return null;
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
    if (_isPinForm) {
      await _loadPinStatuses();
    }
  }

  Future<void> _loadPinStatuses() async {
    if (!_isPinForm) return;
    setState(() {
      _pinStatusesLoading = true;
      _pinStatusError = null;
    });
    try {
      final statuses = await ref
          .read(employeeJobRepositoryProvider)
          .fetchActivePinStatuses();
      if (!mounted) return;
      setState(() {
        _pinStatuses = statuses;
        _pinStatusesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pinStatusesLoading = false;
        _pinStatusError = ApiResponseMessage.fromAnyError(error);
      });
    }
  }

  PinStatusItem? _pinStatusForName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final status in _pinStatuses) {
      if (status.statusName.trim().toLowerCase() == normalized) {
        return status;
      }
    }
    return null;
  }

  Future<void> _updatePinStatus(PinStatusItem status) async {
    if (_pinStatusSaving) return;
    final pin = _resolvedPin;
    final job = ref.read(employeeJobDetailControllerProvider).job;
    final jobId = _resolvedJobId;
    final statusId = int.tryParse(status.id.trim());
    if (pin == null ||
        job == null ||
        jobId == null ||
        statusId == null ||
        statusId <= 0) {
      return;
    }

    final currentStatus = pin.statusName.trim().toLowerCase();
    if (currentStatus == status.statusName.trim().toLowerCase()) return;

    setState(() {
      _pinStatusSaving = true;
      _pinStatusError = null;
    });

    try {
      await ref.read(employeeJobRepositoryProvider).updateDrawingPinStatus(
            jobId: jobId,
            pin: pin,
            levels: job.levels,
            statusId: statusId,
          );
      await ref.read(employeeJobDetailControllerProvider.notifier).load(jobId: jobId);
      OperativeCanvasBridge.notifyCompletionChanged(jobId);
      if (!mounted) return;
      setState(() {
        _pinStatusSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pinStatusSaving = false;
        _pinStatusError = ApiResponseMessage.fromAnyError(error);
      });
      context.showTopSnackBar(
        SnackBar(content: Text(_pinStatusError!)),
      );
    }
  }

  Future<void> _resolveExistingSubmissionId() async {
    if (widget.submissionId != null && widget.submissionId! > 0) {
      _existingSubmissionId = widget.submissionId;
      return;
    }

    if (_isPinForm) {
      final pinSubmissionId = _resolvedPin?.projectFormSubmissionId;
      if (pinSubmissionId != null && pinSubmissionId > 0) {
        _existingSubmissionId = pinSubmissionId;
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
      final pin = _resolvedPin;
      final result = await ref.read(jobQrScanRepositoryProvider).processScan(
            qrCode: normalized,
            jobId: _resolvedJobId ?? widget.jobId,
            jobPinId: widget.jobPinId ??
                pin?.jobPinId ??
                pin?.resolvedJobFormId,
          );
      if (!mounted) return;

      final pinKey = _pinFormKey;
      if (_isPinForm && pinKey != null) {
        ref.read(employeeJobDetailControllerProvider.notifier).markPinQrCodeScanned(
              pinFormKey: pinKey,
              qrCode: result.qrCode,
            );
        final jobId = _resolvedJobId ?? widget.jobId;
        if (jobId != null) {
          await ref
              .read(employeeJobDetailControllerProvider.notifier)
              .load(jobId: jobId);
        }
      }

      if (!mounted) return;
      setState(() {});
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            result.queuedOffline
                ? 'QR scan saved offline. It will sync when you are back online.'
                : result.message?.trim().isNotEmpty == true
                    ? result.message!
                    : _isPinForm
                        ? 'QR assigned to this pin.'
                        : result.registeredWithJob
                            ? 'QR scanned successfully'
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
    if (_restoredValues && _pendingRestoreValues == null) return;
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
    if (!mounted) return;

    if (saved == null || saved.isEmpty) {
      _restoredValues = true;
      _pendingRestoreValues = null;
      if (mounted) setState(() {});
      return;
    }

    // DynamicFormView may not be mounted yet when _loadForm finishes — keep
    // values pending and apply once the form key has a state.
    final applied = _applyRestoredValues(saved);
    if (!applied) {
      _pendingRestoreValues = saved;
    }
    if (mounted) setState(() {});
  }

  bool _applyRestoredValues(List<JobFormFieldValue> values) {
    final formState = _dynamicFormKey.currentState;
    if (formState == null) return false;
    formState.applyFieldValues(values);
    _pendingRestoreValues = null;
    _restoredValues = true;
    return true;
  }

  void _flushPendingRestore() {
    final pending = _pendingRestoreValues;
    if (pending == null || pending.isEmpty) return;
    _applyRestoredValues(pending);
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
      await ref.read(jobFormSubmissionRepositoryProvider).saveDraft(
            jobId: jobId,
            formTemplateId: widget.formId,
            jobFormId: jobFormId,
            jobPinId: widget.jobPinId,
            values: await formState.collectApiValuesAsync(),
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
    final selectedPinStatus = resolvedPin == null
        ? null
        : _pinStatusForName(resolvedPin.statusName);
    final requiredFieldsComplete = _dynamicFormKey.currentState
            ?.areRequiredFieldsComplete(ignoreQrFields: pinRequiresQr) ??
        false;
    final showPinQrSection =
        pinRequiresQr && (requiredFieldsComplete || pinQrComplete);
    final pinAttachments = resolvedPin?.attachments
            .where((attachment) => attachment.hasUrl)
            .toList(growable: false) ??
        const <EmployeeJobPinAttachment>[];

    if (formState.bundle != null &&
        (!_restoredValues || _pendingRestoreValues != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _flushPendingRestore();
        if (_restoredValues && _pendingRestoreValues == null) return;
        await _resolveExistingSubmissionId();
        await _restoreSavedValues();
        if (mounted) _flushPendingRestore();
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
                                  if (_isPinForm && resolvedPin != null) ...[
                                    _PinFormHeaderCard(
                                      pin: resolvedPin,
                                      statuses: _pinStatuses,
                                      selectedStatus: selectedPinStatus,
                                      statusesLoading: _pinStatusesLoading,
                                      statusSaving: _pinStatusSaving,
                                      statusError: _pinStatusError,
                                      onStatusSelected: _updatePinStatus,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
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
                                  DynamicFormView(
                                    key: _dynamicFormKey,
                                    bundle: formState.bundle!,
                                    hideQrFields: pinRequiresQr,
                                    onChanged: () {
                                      _flushPendingRestore();
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
                                      qrCodeId: scannedPinQrCode,
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

class _PinFormHeaderCard extends StatelessWidget {
  const _PinFormHeaderCard({
    required this.pin,
    required this.statuses,
    required this.selectedStatus,
    required this.statusesLoading,
    required this.statusSaving,
    required this.statusError,
    required this.onStatusSelected,
  });

  final EmployeeJobDrawingPin pin;
  final List<PinStatusItem> statuses;
  final PinStatusItem? selectedStatus;
  final bool statusesLoading;
  final bool statusSaving;
  final String? statusError;
  final ValueChanged<PinStatusItem> onStatusSelected;

  PinStatusItem? get _resolvedSelected {
    if (selectedStatus != null) return selectedStatus;
    if (statuses.isEmpty) return null;
    final needle = pin.statusName.trim().toLowerCase();
    for (final s in statuses) {
      if (s.statusName.trim().toLowerCase() == needle) return s;
    }
    return statuses.first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (statusesLoading)
          const LinearProgressIndicator(minHeight: 3)
        else if (statuses.isEmpty)
          Text(
            'No pin statuses available.',
            style: AppFonts.bodySmall(color: AppColors.muted),
          )
        else
          Opacity(
            opacity: statusSaving ? 0.65 : 1,
            child: IgnorePointer(
              ignoring: statusSaving,
              child: _PinStatusDropdown(
                statuses: statuses,
                selected: _resolvedSelected,
                onSelected: onStatusSelected,
              ),
            ),
          ),
        if (statusSaving) ...[
          const SizedBox(height: 8),
          Text(
            'Updating status…',
            style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (statusError != null && statusError!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            statusError!,
            style: AppFonts.bodySmall(color: AppColors.error).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _PinStatusDropdown extends StatefulWidget {
  const _PinStatusDropdown({
    required this.statuses,
    required this.selected,
    required this.onSelected,
  });

  final List<PinStatusItem> statuses;
  final PinStatusItem? selected;
  final ValueChanged<PinStatusItem> onSelected;

  @override
  State<_PinStatusDropdown> createState() => _PinStatusDropdownState();
}

class _PinStatusDropdownState extends State<_PinStatusDropdown> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  void _select(PinStatusItem status) {
    setState(() => _open = false);
    final selected = widget.selected;
    final same = selected != null &&
        (status.id == selected.id ||
            status.statusName.trim().toLowerCase() ==
                selected.statusName.trim().toLowerCase());
    if (!same) widget.onSelected(status);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final borderColor =
        _open ? const Color(0xFF93C5FD) : AppColors.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: selected == null
                        ? Text(
                            'Select status',
                            style: AppFonts.bodyMedium(color: AppColors.muted),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: _PinStatusBadge(status: selected),
                          ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowElevated,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.statuses.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    Builder(
                      builder: (context) {
                        final status = widget.statuses[i];
                        final isSelected = selected != null &&
                            (status.id == selected.id ||
                                status.statusName.trim().toLowerCase() ==
                                    selected.statusName.trim().toLowerCase());
                        return _PinStatusDropdownRow(
                          status: status,
                          selected: isSelected,
                          onTap: () => _select(status),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PinStatusDropdownRow extends StatelessWidget {
  const _PinStatusDropdownRow({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final PinStatusItem status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3F4F6) : AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _PinStatusBadge(status: status),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: Color(0xFF2563EB),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinStatusBadge extends StatelessWidget {
  const _PinStatusBadge({required this.status});

  final PinStatusItem status;

  /// API pin colours are often white-on-solid for map markers. On a light
  /// dropdown chip, pick a dark-enough accent so the status name stays visible.
  static Color _accentColor(Color? text, Color? bg) {
    if (text != null && text.computeLuminance() < 0.55) return text;
    if (bg != null && bg.computeLuminance() < 0.55) return bg;
    return AppColors.inkStrong;
  }

  @override
  Widget build(BuildContext context) {
    final apiText = parseHexColor(status.textColour);
    final apiBg = parseHexColor(status.bgColour);
    final accent = _accentColor(apiText, apiBg);
    final chipBg = apiBg != null && apiBg.computeLuminance() > 0.72
        ? apiBg
        : accent.withValues(alpha: 0.14);
    final icon = _glyphForStatusName(status.statusName);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: AppColors.white),
          ),
          const SizedBox(width: 8),
          Text(
            status.statusName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.bodySmall(color: accent).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _glyphForStatusName(String raw) {
  final name = raw.trim().toLowerCase();
  if (name.contains('cancel') || name.contains('reject')) {
    return Icons.close_rounded;
  }
  if (name.contains('action') ||
      name.contains('required') ||
      name.contains('issue') ||
      name.contains('alert') ||
      name.contains('ongoing')) {
    return Icons.priority_high_rounded;
  }
  if (name.contains('inspect') ||
      name.contains('complete') ||
      name.contains('done') ||
      name.contains('install') ||
      name.contains('finish')) {
    return Icons.check_rounded;
  }
  if (name.contains('progress')) {
    return Icons.check_rounded;
  }
  if (name.contains('todo') ||
      name.contains('to do') ||
      name.contains('pending')) {
    return Icons.nightlight_round;
  }
  if (name.contains('draft')) {
    return Icons.circle_outlined;
  }
  return Icons.circle_rounded;
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
                    'Installation Manual',
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
    required this.qrCodeId,
    required this.enabled,
    required this.onScan,
  });

  final bool isComplete;
  final String? qrCodeId;
  final bool enabled;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final code = qrCodeId?.trim();
    final hasCode = code != null && code.isNotEmpty;

    // Linked: show only the qr_code_id value at the bottom of the form.
    if (isComplete && hasCode) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          code,
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.2,
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
                  'QR code ID',
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
