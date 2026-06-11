import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/forms/data/technician_form_repository.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';
import 'package:red5/employee_role/projects/data/employee_project_repository.dart';

final employeeProjectDetailControllerProvider =
    StateNotifierProvider.autoDispose<
      EmployeeProjectDetailController,
      EmployeeProjectDetailState
    >((ref) {
      return EmployeeProjectDetailController(
        ref.read(employeeProjectRepositoryProvider),
        ref.read(technicianFormRepositoryProvider),
      );
    });

enum EmployeeProjectDetailTab { overview, jobs }

final class EmployeeProjectDetailState {
  const EmployeeProjectDetailState({
    this.project,
    this.isLoading = false,
    this.errorMessage,
    this.selectedTab = EmployeeProjectDetailTab.overview,
    this.isPreloadingForms = false,
  });

  final EmployeeProjectDetail? project;
  final bool isLoading;
  final String? errorMessage;
  final EmployeeProjectDetailTab selectedTab;
  final bool isPreloadingForms;

  EmployeeProjectDetailState copyWith({
    EmployeeProjectDetail? project,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    EmployeeProjectDetailTab? selectedTab,
    bool? isPreloadingForms,
  }) {
    return EmployeeProjectDetailState(
      project: project ?? this.project,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      selectedTab: selectedTab ?? this.selectedTab,
      isPreloadingForms: isPreloadingForms ?? this.isPreloadingForms,
    );
  }
}

final class EmployeeProjectDetailController
    extends StateNotifier<EmployeeProjectDetailState> {
  EmployeeProjectDetailController(this._repository, this._formRepository)
    : super(const EmployeeProjectDetailState());

  final EmployeeProjectRepository _repository;
  final TechnicianFormRepository _formRepository;

  Future<void> load({int? projectId, String? projectName}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final project = await _repository.fetchProjectDetail(
        projectId: projectId,
        projectName: projectName,
      );
      state = state.copyWith(
        project: project,
        isLoading: false,
        clearError: true,
      );
      await _preloadProjectForms(project.formIds);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load project details.',
      );
    }
  }

  Future<void> _preloadProjectForms(List<int> formIds) async {
    if (formIds.isEmpty) return;
    state = state.copyWith(isPreloadingForms: true);
    for (final formId in formIds) {
      try {
        await _formRepository.loadForm(formId);
      } catch (_) {
        // Best-effort cache warm-up for offline technician forms.
      }
    }
    if (!mounted) return;
    state = state.copyWith(isPreloadingForms: false);
  }

  void selectTab(EmployeeProjectDetailTab tab) {
    state = state.copyWith(selectedTab: tab);
  }
}
