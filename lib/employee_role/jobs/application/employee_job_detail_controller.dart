import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';
import 'package:red5/employee_role/forms/application/technician_form_controller.dart';
import 'package:red5/employee_role/forms/data/technician_form_repository.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_detail_widgets.dart';

final employeeJobDetailControllerProvider =
    StateNotifierProvider.autoDispose<
      EmployeeJobDetailController,
      EmployeeJobDetailState
    >((ref) {
      return EmployeeJobDetailController(
        ref.read(employeeJobRepositoryProvider),
        ref.read(jobFormSubmissionRepositoryProvider),
        ref,
      );
    });

enum EmployeeJobDetailTab { forms, designs, location }

final class EmployeeJobDetailState {
  const EmployeeJobDetailState({
    this.job,
    this.isLoading = false,
    this.errorMessage,
    this.isShowingCachedData = false,
    this.selectedTab = EmployeeJobDetailTab.forms,
    this.materialUsed = '',
    this.beforePhotoBytes,
    this.beforePhotoName,
    this.afterPhotoBytes,
    this.afterPhotoName,
    this.customerSignatureCaptured = false,
    this.qrCodeScanned = false,
    this.formIds = const [],
    this.selectedFormId,
    this.completedFormIds = const {},
    this.formTitles = const {},
    this.formSubmissionIds = const {},
    this.completedPinFormKeys = const {},
    this.formHasQrFields = const {},
    this.scannedPinQrKeys = const {},
  });

  final EmployeeJobDetail? job;
  final bool isLoading;
  final String? errorMessage;
  final bool isShowingCachedData;
  final EmployeeJobDetailTab selectedTab;
  final String materialUsed;
  final Uint8List? beforePhotoBytes;
  final String? beforePhotoName;
  final Uint8List? afterPhotoBytes;
  final String? afterPhotoName;
  final bool customerSignatureCaptured;
  final bool qrCodeScanned;

  bool get hasJobPhotos =>
      beforePhotoBytes != null && afterPhotoBytes != null;
  final List<int> formIds;
  final int? selectedFormId;
  final Set<int> completedFormIds;
  final Map<int, String> formTitles;
  final Map<int, int> formSubmissionIds;
  final Set<String> completedPinFormKeys;
  final Map<int, bool> formHasQrFields;
  final Set<String> scannedPinQrKeys;

  bool get hasPinQrForms => formHasQrFields.values.any((value) => value);

  bool get hasMultipleForms => formIds.length > 1;

  bool get hasPinFormTasks =>
      (job?.pinFormTasks ?? const []).isNotEmpty;

  bool get allRequiredFormsComplete {
    final pinTasks = job?.pinFormTasks ?? const [];
    if (pinTasks.isNotEmpty) {
      return pinTasks.every(
        (task) => completedPinFormKeys.contains(task.key),
      );
    }
    return formIds.isNotEmpty && formIds.every(completedFormIds.contains);
  }

  String titleForForm(int formId) =>
      formTitles[formId]?.trim().isNotEmpty == true
      ? formTitles[formId]!.trim()
      : 'Form $formId';

  EmployeeJobDetailState copyWith({
    EmployeeJobDetail? job,
    bool? isLoading,
    String? errorMessage,
    bool? isShowingCachedData,
    bool clearError = false,
    EmployeeJobDetailTab? selectedTab,
    String? materialUsed,
    Uint8List? beforePhotoBytes,
    String? beforePhotoName,
    Uint8List? afterPhotoBytes,
    String? afterPhotoName,
    bool? customerSignatureCaptured,
    bool? qrCodeScanned,
    List<int>? formIds,
    int? selectedFormId,
    Set<int>? completedFormIds,
    Map<int, String>? formTitles,
    Map<int, int>? formSubmissionIds,
    Set<String>? completedPinFormKeys,
    Map<int, bool>? formHasQrFields,
    Set<String>? scannedPinQrKeys,
  }) {
    return EmployeeJobDetailState(
      job: job ?? this.job,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isShowingCachedData: isShowingCachedData ?? this.isShowingCachedData,
      selectedTab: selectedTab ?? this.selectedTab,
      materialUsed: materialUsed ?? this.materialUsed,
      beforePhotoBytes: beforePhotoBytes ?? this.beforePhotoBytes,
      beforePhotoName: beforePhotoName ?? this.beforePhotoName,
      afterPhotoBytes: afterPhotoBytes ?? this.afterPhotoBytes,
      afterPhotoName: afterPhotoName ?? this.afterPhotoName,
      customerSignatureCaptured:
          customerSignatureCaptured ?? this.customerSignatureCaptured,
      qrCodeScanned: qrCodeScanned ?? this.qrCodeScanned,
      formIds: formIds ?? this.formIds,
      selectedFormId: selectedFormId ?? this.selectedFormId,
      completedFormIds: completedFormIds ?? this.completedFormIds,
      formTitles: formTitles ?? this.formTitles,
      formSubmissionIds: formSubmissionIds ?? this.formSubmissionIds,
      completedPinFormKeys: completedPinFormKeys ?? this.completedPinFormKeys,
      formHasQrFields: formHasQrFields ?? this.formHasQrFields,
      scannedPinQrKeys: scannedPinQrKeys ?? this.scannedPinQrKeys,
    );
  }

  bool get isJobCompleted {
    final job = this.job;
    if (job == null) return false;
    final status = job.currentStatus.trim().toUpperCase();
    return status.contains('COMPLETE');
  }
}

final class EmployeeJobDetailController
    extends StateNotifier<EmployeeJobDetailState> {
  EmployeeJobDetailController(
    this._repository,
    this._submissionRepository,
    this._ref,
  ) : super(const EmployeeJobDetailState());

  final EmployeeJobRepository _repository;
  final JobFormSubmissionRepository _submissionRepository;
  final Ref _ref;

  ({
    List<int> formIds,
    List<JobFormAssignment> formAssignments,
    Map<int, String> formTitles,
    Map<int, int> formSubmissionIds,
  }) _formsStateFromJobDetail({
    required List<JobLinkedFormSummary> jobForms,
    required List<JobFormAssignment> seedAssignments,
    Map<int, int> seedSubmissionIds = const {},
  }) {
    var formAssignments = List<JobFormAssignment>.from(seedAssignments);
    var formIds = jobForms.isNotEmpty
        ? jobForms.map((form) => form.formId).toList(growable: false)
        : formAssignments.isNotEmpty
            ? formAssignments.map((assignment) => assignment.formId).toList()
            : <int>[];
    final formTitles = <int, String>{
      for (final form in jobForms)
        if (form.name.trim().isNotEmpty) form.formId: form.name.trim(),
    };
    final formSubmissionIds = Map<int, int>.from(seedSubmissionIds);

    if (jobForms.isNotEmpty) {
      formAssignments = JobFormAssignment.mergeByFormId(
        formAssignments,
        JobFormAssignment.fromLinkedForms(jobForms),
      );
      for (final form in jobForms) {
        final submissionId = form.submissionId;
        if (submissionId != null && submissionId > 0) {
          formSubmissionIds[form.formId] = submissionId;
        }
      }
    }

    formIds = formIds.toSet().toList(growable: false);

    for (final assignment in formAssignments) {
      final submissionId = assignment.submissionId;
      if (submissionId != null && submissionId > 0) {
        formSubmissionIds[assignment.formId] = submissionId;
      }
    }

    return (
      formIds: formIds,
      formAssignments: formAssignments,
      formTitles: formTitles,
      formSubmissionIds: formSubmissionIds,
    );
  }

  String liveStatusLabel({required bool formsIncomplete}) {
    final job = state.job;
    if (job == null) return '—';
    if (formsIncomplete) return EmployeeJobStatus.inProgress.label;
    return _ref.read(employeeJobSessionProvider.notifier).resolveStatusLabel(
          jobId: job.id,
          apiStatusLabel: job.currentStatus,
        );
  }

  Future<EmployeeJobDetail> _syncOperativeJobStatus(EmployeeJobDetail job) async {
    final session = _ref.read(employeeJobSessionProvider.notifier);
    final apiStatus =
        EmployeeJobSessionController.statusFromLabel(job.currentStatus);

    if (apiStatus == EmployeeJobStatus.completed ||
        session.isJobCompleted(job.id)) {
      return job;
    }

    if (apiStatus == EmployeeJobStatus.inProgress || session.isJobStarted(job.id)) {
      session.ensureJobSessionHydrated(job.id);
      if (apiStatus != EmployeeJobStatus.inProgress) {
        try {
          return await _repository.fetchJobDetail(jobId: job.id);
        } catch (_) {}
      }
      return job;
    }

    if (job.safetyChecklist.isNotEmpty) {
      return job;
    }

    try {
      await _repository.markJobStarted(job.id);
      session.startJob(job.id);
      return _repository.fetchJobDetail(jobId: job.id);
    } catch (_) {
      session.startJob(job.id);
      return job;
    }
  }

  Future<void> load({int? jobId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final fetchResult = await _repository.fetchJobDetailWithSource(jobId: jobId);
      var job = await _syncOperativeJobStatus(fetchResult.detail);
      final jobForms = job.jobForms;
      var formsState = _formsStateFromJobDetail(
        jobForms: jobForms,
        seedAssignments: job.formAssignments,
        seedSubmissionIds: {
          for (final assignment in job.formAssignments)
            if (assignment.submissionId != null && assignment.submissionId! > 0)
              assignment.formId: assignment.submissionId!,
        },
      );

      if (formsState.formAssignments.isNotEmpty) {
        await _submissionRepository.cacheJobFormLinks(
          jobId: job.id,
          assignments: formsState.formAssignments,
        );
      }

      try {
        await _submissionRepository.refreshJobFormLinksFromApi(job.id);
      } catch (_) {}

      final refreshedAssignments =
          await _submissionRepository.cachedAssignmentsForJob(job.id);
      if (refreshedAssignments.isNotEmpty) {
        formsState = _formsStateFromJobDetail(
          jobForms: jobForms,
          seedAssignments: JobFormAssignment.mergeByFormId(
            formsState.formAssignments,
            refreshedAssignments,
          ),
          seedSubmissionIds: formsState.formSubmissionIds,
        );
      }

      final enrichedJobWithLinks = job.copyWith(
        formIds: formsState.formIds,
        formAssignments: formsState.formAssignments,
        jobForms: jobForms,
      );

      state = state.copyWith(
        job: enrichedJobWithLinks,
        isLoading: false,
        isShowingCachedData: fetchResult.fromCache,
        clearError: true,
        formIds: formsState.formIds,
        selectedFormId: null,
        completedFormIds: const {},
        formTitles: formsState.formTitles,
        formSubmissionIds: formsState.formSubmissionIds,
      );

      if (formsState.formIds.isNotEmpty || job.pinFormTasks.isNotEmpty) {
        await _preloadFormTitles(formsState.formIds);
        if (job.pinFormTasks.isNotEmpty) {
          await _preloadFormQrFlags(job.pinFormTasks);
        }
        if (formsState.formIds.isNotEmpty) {
          await _loadCompletedForms(
            job.id,
            formsState.formIds,
            enrichedJobWithLinks.formAssignments,
          );
          await _loadSubmissionIds(job.id, formsState.formIds);
        }
        if (job.pinFormTasks.isNotEmpty) {
          await _syncCompletedPinForms(job.pinFormTasks);
        }
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load job details.',
      );
    }
  }

  Future<void> _preloadFormQrFlags(
    List<EmployeeJobPinFormTask> tasks,
  ) async {
    if (tasks.isEmpty) return;
    final repository = _ref.read(technicianFormRepositoryProvider);
    final flags = Map<int, bool>.from(state.formHasQrFields);
    final formIds = tasks.map((task) => task.formId).toSet();

    await Future.wait(
      formIds.map((formId) async {
        if (flags.containsKey(formId)) return;
        try {
          final bundle = await repository.loadForm(formId);
          flags[formId] = formMetadataHasQrFields(bundle.metadata);
        } catch (_) {
          flags[formId] = false;
        }
      }),
    );

    state = state.copyWith(formHasQrFields: flags);
  }

  Future<void> _syncCompletedPinForms(
    List<EmployeeJobPinFormTask> tasks,
  ) async {
    if (tasks.isEmpty) return;
    final job = state.job;
    if (job == null) return;

    final keys = Set<String>.from(state.completedPinFormKeys);
    for (final task in tasks) {
      final pin = findEmployeeJobPinById(job.levels, task.pinId);
      if (pin?.isStatusComplete == true) {
        keys.add(task.key);
        continue;
      }

      final jobFormId = task.jobFormId ?? task.pinId;
      final linkedForm = job.jobForms
          .where((form) => form.jobFormId == jobFormId)
          .toList(growable: false);
      if (linkedForm.any((form) => form.isSubmitted)) {
        keys.add(task.key);
      }
    }

    state = state.copyWith(completedPinFormKeys: keys);
  }

  Future<void> _loadCompletedForms(
    int jobId,
    List<int> formIds,
    List<JobFormAssignment> assignments,
  ) async {
    try {
      final completed = await _submissionRepository.completedFormIdsForJob(
        jobId: jobId,
        formIds: formIds,
        assignments: assignments,
      );
      state = state.copyWith(
        completedFormIds: completed
            .where((formId) => formIds.contains(formId))
            .toSet(),
      );
    } catch (_) {
      // Best-effort: local cache still drives completion when offline.
    }
  }

  /// Re-fetches linked forms from `GET /jobs/{id}/` (e.g. when new forms are attached mid-job).
  Future<void> refreshAttachedForms() async {
    final job = state.job;
    if (job == null) return;

    try {
      final jobForms = await _repository.fetchJobForms(jobId: job.id);
      final refreshedAssignments =
          await _submissionRepository.refreshJobFormLinksFromApi(job.id);

      final formsState = _formsStateFromJobDetail(
        jobForms: jobForms,
        seedAssignments: JobFormAssignment.mergeByFormId(
          job.formAssignments,
          refreshedAssignments,
        ),
        seedSubmissionIds: state.formSubmissionIds,
      );

      state = state.copyWith(
        job: job.copyWith(
          formIds: formsState.formIds,
          formAssignments: formsState.formAssignments,
          jobForms: jobForms,
        ),
        formIds: formsState.formIds,
        formTitles: {
          ...state.formTitles,
          ...formsState.formTitles,
        },
        formSubmissionIds: formsState.formSubmissionIds,
      );

      if (formsState.formIds.isNotEmpty) {
        await _loadCompletedForms(
          job.id,
          formsState.formIds,
          formsState.formAssignments,
        );
      } else {
        state = state.copyWith(completedFormIds: const {});
      }

      if (job.pinFormTasks.isNotEmpty) {
        await _preloadFormQrFlags(job.pinFormTasks);
        await _syncCompletedPinForms(job.pinFormTasks);
      }

      if (!state.allRequiredFormsComplete) {
        _ref.read(employeeJobSessionProvider.notifier).reopenJob(job.id);
      }
    } catch (_) {
      // Best-effort refresh when offline or API fails.
    }
  }

  Future<void> refreshCompletedForms() async {
    await refreshAttachedForms();
    final job = state.job;
    if (job == null || state.formIds.isEmpty) return;
    await _loadSubmissionIds(job.id, state.formIds);
  }

  int? jobFormIdFor(int formTemplateId) {
    final job = state.job;
    if (job == null) return null;
    return job.jobFormIdFor(formTemplateId);
  }

  int? submissionIdFor(int formTemplateId) => state.formSubmissionIds[formTemplateId];

  bool get isJobCompleted {
    final job = state.job;
    if (job == null) return false;
    if (state.formIds.isNotEmpty && !state.allRequiredFormsComplete) {
      return false;
    }
    if (state.isJobCompleted) return true;
    return _ref.read(employeeJobSessionProvider.notifier).isJobCompleted(job.id);
  }

  bool get allRequiredFormsComplete => state.allRequiredFormsComplete;

  Future<void> _loadSubmissionIds(int jobId, List<int> formIds) async {
    final ids = Map<int, int>.from(state.formSubmissionIds);

    try {
      final submitted =
          await _submissionRepository.fetchSubmittedFormsRemote(jobId);
      for (final row in submitted) {
        final formId = row.formId;
        final submissionId = row.resolvedSubmissionId;
        if (formId == null ||
            !formIds.contains(formId) ||
            submissionId == null ||
            submissionId <= 0) {
          continue;
        }
        ids[formId] = submissionId;
      }
    } catch (_) {
      // Best-effort: per-form resolution still runs below.
    }

    await Future.wait(
      formIds.map((formId) async {
        if (ids.containsKey(formId)) return;
        try {
          final submissionId = await _submissionRepository.resolveSubmissionId(
            jobId: jobId,
            formTemplateId: formId,
          );
          if (submissionId != null && submissionId > 0) {
            ids[formId] = submissionId;
          }
        } catch (_) {
          // Best-effort: updates still resolve on submit.
        }
      }),
    );
    if (ids.length != state.formSubmissionIds.length ||
        ids.entries.any(
          (entry) => state.formSubmissionIds[entry.key] != entry.value,
        )) {
      state = state.copyWith(formSubmissionIds: ids);
    }
  }

  Future<void> _preloadFormTitles(List<int> formIds) async {
    final repository = _ref.read(technicianFormRepositoryProvider);
    final titles = Map<int, String>.from(state.formTitles);

    await Future.wait(
      formIds.map((formId) async {
        if (titles[formId]?.trim().isNotEmpty == true) return;
        try {
          final bundle = await repository.loadForm(formId);
          titles[formId] = bundle.summary.name;
        } catch (_) {
          titles[formId] = 'Form $formId';
        }
      }),
    );

    state = state.copyWith(formTitles: titles);
  }

  Future<void> selectForm(int formId) async {
    if (!state.formIds.contains(formId)) return;
    state = state.copyWith(selectedFormId: formId);
    await _ref.read(technicianFormControllerProvider.notifier).load(formId);
    final bundle = _ref.read(technicianFormControllerProvider).bundle;
    if (bundle != null) {
      final titles = Map<int, String>.from(state.formTitles)
        ..[formId] = bundle.summary.name;
      state = state.copyWith(formTitles: titles);
    }
  }

  void markQrCodeScanned({int? pinId, int? formId}) {
    if (pinId != null && formId != null && formId > 0) {
      final pinKeys = Set<String>.from(state.scannedPinQrKeys)
        ..add('${pinId}_$formId');
      state = state.copyWith(scannedPinQrKeys: pinKeys);
      return;
    }
    state = state.copyWith(qrCodeScanned: true);
  }

  void markFormComplete(int formId, {int? pinId}) {
    final pinTasks = state.job?.pinFormTasks ?? const [];
    final isPinForm = pinTasks.any((task) => task.formId == formId);
    if (!state.formIds.contains(formId) && !isPinForm) return;
    final updated = Set<int>.from(state.completedFormIds)..add(formId);
    final pinKeys = Set<String>.from(state.completedPinFormKeys);
    if (pinId != null) {
      pinKeys.add('${pinId}_$formId');
    }
    state = state.copyWith(
      completedFormIds: updated,
      completedPinFormKeys: pinKeys,
    );
  }

  void setSubmissionId({required int formId, required int submissionId}) {
    if (!state.formIds.contains(formId) || submissionId <= 0) return;
    final ids = Map<int, int>.from(state.formSubmissionIds)
      ..[formId] = submissionId;
    state = state.copyWith(formSubmissionIds: ids);
  }

  void markSelectedFormComplete() {
    final formId = state.selectedFormId;
    if (formId == null) return;
    markFormComplete(formId);
  }

  bool canSubmit({required bool dynamicFormComplete}) {
    final job = state.job;
    if (job == null) return false;
    final items = buildEmployeeRequiredFormItems(
      job: job,
      formIds: state.formIds,
      completedFormIds: state.completedFormIds,
      completedPinFormKeys: state.completedPinFormKeys,
      hasQrScan: state.qrCodeScanned,
      dynamicFormComplete: dynamicFormComplete,
      isJobCompleted: isJobCompleted,
      formHasQrFields: state.formHasQrFields,
    );
    return items
        .where((item) => !item.isOptional)
        .every((item) => item.isComplete);
  }

  void selectTab(EmployeeJobDetailTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void toggleChecklistItem(String id, bool value) {
    final job = state.job;
    if (job == null) return;
    state = state.copyWith(
      job: job.copyWith(
        safetyChecklist: [
          for (final item in job.safetyChecklist)
            item.id == id ? item.copyWith(isChecked: value) : item,
        ],
      ),
    );
  }

  void updateMaterialUsed(String value) {
    state = state.copyWith(materialUsed: value);
  }

  void setBeforePhoto({required Uint8List bytes, required String name}) {
    state = state.copyWith(beforePhotoBytes: bytes, beforePhotoName: name);
  }

  void setAfterPhoto({required Uint8List bytes, required String name}) {
    state = state.copyWith(afterPhotoBytes: bytes, afterPhotoName: name);
  }

  void setJobPhotos({
    required Uint8List beforeBytes,
    required String beforeName,
    required Uint8List afterBytes,
    required String afterName,
  }) {
    state = state.copyWith(
      beforePhotoBytes: beforeBytes,
      beforePhotoName: beforeName,
      afterPhotoBytes: afterBytes,
      afterPhotoName: afterName,
    );
  }

  void setCustomerSignatureCaptured(bool value) {
    state = state.copyWith(customerSignatureCaptured: value);
  }
}
