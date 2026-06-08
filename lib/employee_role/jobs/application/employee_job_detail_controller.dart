import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';

final employeeJobDetailControllerProvider =
    StateNotifierProvider.autoDispose<
      EmployeeJobDetailController,
      EmployeeJobDetailState
    >((ref) {
      return EmployeeJobDetailController(
        ref.read(employeeJobRepositoryProvider),
      );
    });

enum EmployeeJobDetailTab { form, location }

final class EmployeeJobDetailState {
  const EmployeeJobDetailState({
    this.job,
    this.isLoading = false,
    this.errorMessage,
    this.selectedTab = EmployeeJobDetailTab.form,
    this.materialUsed = '',
    this.beforePhotoBytes,
    this.beforePhotoName,
  });

  final EmployeeJobDetail? job;
  final bool isLoading;
  final String? errorMessage;
  final EmployeeJobDetailTab selectedTab;
  final String materialUsed;
  final Uint8List? beforePhotoBytes;
  final String? beforePhotoName;

  EmployeeJobDetailState copyWith({
    EmployeeJobDetail? job,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    EmployeeJobDetailTab? selectedTab,
    String? materialUsed,
    Uint8List? beforePhotoBytes,
    String? beforePhotoName,
  }) {
    return EmployeeJobDetailState(
      job: job ?? this.job,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      selectedTab: selectedTab ?? this.selectedTab,
      materialUsed: materialUsed ?? this.materialUsed,
      beforePhotoBytes: beforePhotoBytes ?? this.beforePhotoBytes,
      beforePhotoName: beforePhotoName ?? this.beforePhotoName,
    );
  }
}

final class EmployeeJobDetailController
    extends StateNotifier<EmployeeJobDetailState> {
  EmployeeJobDetailController(this._repository)
    : super(const EmployeeJobDetailState());

  final EmployeeJobRepository _repository;

  Future<void> load({int? jobId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final job = await _repository.fetchJobDetail(jobId: jobId);
      state = state.copyWith(job: job, isLoading: false, clearError: true);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load job details.',
      );
    }
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
        materials: job.materials,
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
}
