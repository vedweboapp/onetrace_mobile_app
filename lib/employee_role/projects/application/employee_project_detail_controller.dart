import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';
import 'package:red5/employee_role/projects/data/employee_project_repository.dart';

final employeeProjectDetailControllerProvider =
    StateNotifierProvider.autoDispose<
      EmployeeProjectDetailController,
      EmployeeProjectDetailState
    >((ref) {
      return EmployeeProjectDetailController(
        ref.read(employeeProjectRepositoryProvider),
      );
    });

enum EmployeeProjectDetailTab { overview, jobs }

final class EmployeeProjectDetailState {
  const EmployeeProjectDetailState({
    this.project,
    this.isLoading = false,
    this.errorMessage,
    this.selectedTab = EmployeeProjectDetailTab.overview,
  });

  final EmployeeProjectDetail? project;
  final bool isLoading;
  final String? errorMessage;
  final EmployeeProjectDetailTab selectedTab;

  EmployeeProjectDetailState copyWith({
    EmployeeProjectDetail? project,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    EmployeeProjectDetailTab? selectedTab,
  }) {
    return EmployeeProjectDetailState(
      project: project ?? this.project,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

final class EmployeeProjectDetailController
    extends StateNotifier<EmployeeProjectDetailState> {
  EmployeeProjectDetailController(this._repository)
    : super(const EmployeeProjectDetailState());

  final EmployeeProjectRepository _repository;

  Future<void> load({String? projectName}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final project = await _repository.fetchProjectDetail(
        projectName: projectName,
      );
      state = state.copyWith(
        project: project,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load project details.',
      );
    }
  }

  void selectTab(EmployeeProjectDetailTab tab) {
    state = state.copyWith(selectedTab: tab);
  }
}
