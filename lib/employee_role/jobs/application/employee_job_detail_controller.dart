import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/forms/application/technician_form_controller.dart';
import 'package:red5/employee_role/forms/data/technician_form_repository.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_detail_widgets.dart';
import 'package:red5/employee_role/projects/data/employee_project_repository.dart';

final employeeJobDetailControllerProvider =
    StateNotifierProvider.autoDispose<
      EmployeeJobDetailController,
      EmployeeJobDetailState
    >((ref) {
      return EmployeeJobDetailController(
        ref.read(employeeJobRepositoryProvider),
        ref.read(employeeProjectRepositoryProvider),
        ref.read(jobFormSubmissionRepositoryProvider),
        ref,
      );
    });

enum EmployeeJobDetailTab { forms, location }

final class EmployeeJobDetailState {
  const EmployeeJobDetailState({
    this.job,
    this.isLoading = false,
    this.errorMessage,
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
  });

  final EmployeeJobDetail? job;
  final bool isLoading;
  final String? errorMessage;
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

  bool get hasMultipleForms => formIds.length > 1;

  /// Every form currently linked to the job has been saved/submitted locally.
  bool get allRequiredFormsComplete =>
      formIds.isNotEmpty && formIds.every(completedFormIds.contains);

  String titleForForm(int formId) =>
      formTitles[formId]?.trim().isNotEmpty == true
      ? formTitles[formId]!.trim()
      : 'Form $formId';

  EmployeeJobDetailState copyWith({
    EmployeeJobDetail? job,
    bool? isLoading,
    String? errorMessage,
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
  }) {
    return EmployeeJobDetailState(
      job: job ?? this.job,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
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
    this._projectRepository,
    this._submissionRepository,
    this._ref,
  ) : super(const EmployeeJobDetailState());

  final EmployeeJobRepository _repository;
  final EmployeeProjectRepository _projectRepository;
  final JobFormSubmissionRepository _submissionRepository;
  final Ref _ref;

  Future<void> load({int? jobId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final job = await _repository.fetchJobDetail(jobId: jobId);
      var formAssignments = List<JobFormAssignment>.from(job.formAssignments);
      if (formAssignments.isNotEmpty) {
        await _submissionRepository.cacheJobFormLinks(
          jobId: job.id,
          assignments: formAssignments,
        );
      }
      var formIds = formAssignments.isNotEmpty
          ? formAssignments.map((assignment) => assignment.formId).toList()
          : List<int>.from(job.linkedFormIds);

      if (formIds.isEmpty && formAssignments.isEmpty && job.projectId != null) {
        try {
          final project = await _projectRepository.fetchProjectDetail(
            projectId: job.projectId,
          );
          if (project.formIds.isNotEmpty) {
            formIds = List<int>.from(project.formIds);
          }
        } catch (_) {
          // Form preload is best-effort when job has no direct form link.
        }
      }

      formIds = formIds.toSet().toList(growable: false);
      var formTitles = <int, String>{};
      var formSubmissionIds = <int, int>{
        for (final assignment in job.formAssignments)
          if (assignment.submissionId != null && assignment.submissionId! > 0)
            assignment.formId: assignment.submissionId!,
      };
      var linkedForms = const <JobLinkedFormSummary>[];

      try {
        linkedForms =
            await _submissionRepository.fetchLinkedFormsRemote(job.id);
        if (linkedForms.isNotEmpty) {
          formIds = {
            ...formIds,
            ...linkedForms.map((form) => form.formId),
          }.toList(growable: false);

          for (final linked in linkedForms) {
            formTitles[linked.formId] = linked.name;
            final submissionId = linked.submissionId;
            if (submissionId != null && submissionId > 0) {
              formSubmissionIds[linked.formId] = submissionId;
            }
          }
          formAssignments = JobFormAssignment.mergeByFormId(
            formAssignments,
            JobFormAssignment.fromLinkedForms(linkedForms),
          );
        }
      } catch (_) {
        // Linked forms are best-effort when job detail omits them.
      }

      await _submissionRepository.refreshJobFormLinksFromApi(job.id);

      final refreshedAssignments =
          await _submissionRepository.cachedAssignmentsForJob(job.id);
      if (refreshedAssignments.isNotEmpty) {
        formAssignments = JobFormAssignment.mergeByFormId(
          formAssignments,
          refreshedAssignments,
        );
      }

      formIds = {
        ...formIds,
        ...formAssignments.map((assignment) => assignment.formId),
      }.toList(growable: false);

      for (final assignment in formAssignments) {
        final submissionId = assignment.submissionId;
        if (submissionId != null && submissionId > 0) {
          formSubmissionIds[assignment.formId] = submissionId;
        }
      }

      final enrichedJobWithLinks = job.copyWith(
        formIds: formIds,
        formAssignments: formAssignments,
      );

      state = state.copyWith(
        job: enrichedJobWithLinks,
        isLoading: false,
        clearError: true,
        formIds: formIds,
        selectedFormId: null,
        completedFormIds: const {},
        formTitles: formTitles,
        formSubmissionIds: formSubmissionIds,
      );

      if (formIds.isNotEmpty) {
        await Future.wait([
          _preloadFormTitles(formIds),
          _loadCompletedForms(
            job.id,
            formIds,
            enrichedJobWithLinks.formAssignments,
          ),
          _loadSubmissionIds(job.id, formIds),
        ]);
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load job details.',
      );
    }
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

  /// Re-fetches linked forms from the API (e.g. when new forms are attached mid-job).
  Future<void> refreshAttachedForms() async {
    final job = state.job;
    if (job == null) return;

    try {
      final refreshedAssignments =
          await _submissionRepository.refreshJobFormLinksFromApi(job.id);

      var formIds = List<int>.from(state.formIds);
      var formAssignments = List<JobFormAssignment>.from(job.formAssignments);
      var formTitles = Map<int, String>.from(state.formTitles);

      if (refreshedAssignments.isNotEmpty) {
        formAssignments = JobFormAssignment.mergeByFormId(
          formAssignments,
          refreshedAssignments,
        );
        formIds = {
          ...formIds,
          ...refreshedAssignments.map((assignment) => assignment.formId),
        }.toList(growable: false);
      }

      try {
        final linked =
            await _submissionRepository.fetchLinkedFormsRemote(job.id);
        if (linked.isNotEmpty) {
          formIds = {
            ...formIds,
            ...linked.map((form) => form.formId),
          }.toList(growable: false);
          formAssignments = JobFormAssignment.mergeByFormId(
            formAssignments,
            JobFormAssignment.fromLinkedForms(linked),
          );
          for (final row in linked) {
            formTitles[row.formId] = row.name;
          }
        }
      } catch (_) {
        // Linked forms are best-effort.
      }

      state = state.copyWith(
        job: job.copyWith(
          formIds: formIds,
          formAssignments: formAssignments,
        ),
        formIds: formIds,
        formTitles: formTitles,
      );

      if (formIds.isNotEmpty) {
        await _loadCompletedForms(job.id, formIds, formAssignments);
      } else {
        state = state.copyWith(completedFormIds: const {});
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

  void markQrCodeScanned() {
    state = state.copyWith(qrCodeScanned: true);
  }

  void markFormComplete(int formId) {
    if (!state.formIds.contains(formId)) return;
    final updated = Set<int>.from(state.completedFormIds)..add(formId);
    state = state.copyWith(completedFormIds: updated);
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
      hasQrScan: state.qrCodeScanned,
      dynamicFormComplete: dynamicFormComplete,
      isJobCompleted: isJobCompleted,
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
      job: EmployeeJobDetail(
        id: job.id,
        title: job.title,
        currentStatus: job.currentStatus,
        project: job.project,
        client: job.client,
        siteContact: job.siteContact,
        block: job.block,
        plot: job.plot,
        description: job.description,
        items: job.items,
        safetyChecklist: [
          for (final item in job.safetyChecklist)
            item.id == id ? item.copyWith(isChecked: value) : item,
        ],
        formId: job.formId,
        formIds: job.formIds,
        formAssignments: job.formAssignments,
        projectId: job.projectId,
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
