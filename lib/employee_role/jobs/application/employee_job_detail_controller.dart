import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/forms/application/technician_form_controller.dart';
import 'package:red5/employee_role/forms/data/technician_form_repository.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
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
    this.formIds = const [],
    this.selectedFormId,
    this.completedFormIds = const {},
    this.formTitles = const {},
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

  bool get hasJobPhotos =>
      beforePhotoBytes != null && afterPhotoBytes != null;
  final List<int> formIds;
  final int? selectedFormId;
  final Set<int> completedFormIds;
  final Map<int, String> formTitles;

  bool get hasMultipleForms => formIds.length > 1;

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
    List<int>? formIds,
    int? selectedFormId,
    Set<int>? completedFormIds,
    Map<int, String>? formTitles,
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
      formIds: formIds ?? this.formIds,
      selectedFormId: selectedFormId ?? this.selectedFormId,
      completedFormIds: completedFormIds ?? this.completedFormIds,
      formTitles: formTitles ?? this.formTitles,
    );
  }
}

final class EmployeeJobDetailController
    extends StateNotifier<EmployeeJobDetailState> {
  EmployeeJobDetailController(
    this._repository,
    this._projectRepository,
    this._ref,
  ) : super(const EmployeeJobDetailState());

  final EmployeeJobRepository _repository;
  final EmployeeProjectRepository _projectRepository;
  final Ref _ref;

  Future<void> load({int? jobId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final job = await _repository.fetchJobDetail(jobId: jobId);
      var formIds = List<int>.from(job.linkedFormIds);

      if (formIds.isEmpty && job.projectId != null) {
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

      state = state.copyWith(
        job: job,
        isLoading: false,
        clearError: true,
        formIds: formIds,
        selectedFormId: null,
        completedFormIds: const {},
        formTitles: const {},
      );

      if (formIds.isNotEmpty) {
        await _preloadFormTitles(formIds);
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load job details.',
      );
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

  void markFormComplete(int formId) {
    if (!state.formIds.contains(formId)) return;
    final updated = Set<int>.from(state.completedFormIds)..add(formId);
    state = state.copyWith(completedFormIds: updated);
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
      hasBeforePhoto: state.hasJobPhotos,
      hasMaterialUsed: state.materialUsed.trim().isNotEmpty,
      hasCustomerSignature: state.customerSignatureCaptured,
      dynamicFormComplete: dynamicFormComplete,
    );
    return items.every((item) => item.isComplete);
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
