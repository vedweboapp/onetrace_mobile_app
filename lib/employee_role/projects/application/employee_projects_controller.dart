import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';
import 'package:red5/employee_role/projects/data/employee_project_repository.dart';

enum EmployeeProjectFilter { all, active, completed }

final employeeProjectsControllerProvider =
    StateNotifierProvider.autoDispose<
      EmployeeProjectsController,
      EmployeeProjectsState
    >((ref) {
      return EmployeeProjectsController(
        ref.read(employeeProjectRepositoryProvider),
      );
    });

final class EmployeeProjectsState {
  const EmployeeProjectsState({
    this.projects = const [],
    this.isLoading = false,
    this.errorMessage,
    this.filter = EmployeeProjectFilter.all,
    this.searchQuery = '',
  });

  final List<EmployeeProjectSummary> projects;
  final bool isLoading;
  final String? errorMessage;
  final EmployeeProjectFilter filter;
  final String searchQuery;

  List<EmployeeProjectSummary> get visibleProjects {
    final query = searchQuery.trim().toLowerCase();
    return projects.where((project) {
      final matchesFilter = switch (filter) {
        EmployeeProjectFilter.all => true,
        EmployeeProjectFilter.active => !project.isCompleted,
        EmployeeProjectFilter.completed => project.isCompleted,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return project.title.toLowerCase().contains(query) ||
          project.client.toLowerCase().contains(query) ||
          project.site.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  EmployeeProjectsState copyWith({
    List<EmployeeProjectSummary>? projects,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    EmployeeProjectFilter? filter,
    String? searchQuery,
  }) {
    return EmployeeProjectsState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final class EmployeeProjectsController extends StateNotifier<EmployeeProjectsState> {
  EmployeeProjectsController(this._repository)
    : super(const EmployeeProjectsState());

  final EmployeeProjectRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final projects = await _repository.fetchProjects();
      state = state.copyWith(
        projects: projects,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load projects.',
      );
    }
  }

  void setFilter(EmployeeProjectFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}
