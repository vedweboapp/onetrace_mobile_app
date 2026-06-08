import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/projects/data/project_map_job.dart';
import 'package:red5/employee_role/projects/data/project_map_repository.dart';

final projectMapControllerProvider =
    StateNotifierProvider.autoDispose<ProjectMapController, ProjectMapState>((
      ref,
    ) {
      return ProjectMapController(ref.read(projectMapRepositoryProvider));
    });

final class ProjectMapState {
  const ProjectMapState({
    this.jobs = const <ProjectMapJob>[],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedJobId,
    this.isDarkMap = false,
  });

  final List<ProjectMapJob> jobs;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final int? selectedJobId;
  final bool isDarkMap;

  ProjectMapJob? get selectedJob {
    final id = selectedJobId;
    if (id == null) return null;
    for (final job in jobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  ProjectMapState copyWith({
    List<ProjectMapJob>? jobs,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    int? selectedJobId,
    bool clearSelectedJob = false,
    bool? isDarkMap,
  }) {
    return ProjectMapState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedJobId: clearSelectedJob
          ? null
          : selectedJobId ?? this.selectedJobId,
      isDarkMap: isDarkMap ?? this.isDarkMap,
    );
  }
}

final class ProjectMapController extends StateNotifier<ProjectMapState> {
  ProjectMapController(this._repository) : super(const ProjectMapState());

  final ProjectMapRepository _repository;

  Future<void> loadJobs({String? search}) async {
    final query = search ?? state.searchQuery;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      searchQuery: query,
    );
    try {
      final jobs = await _repository.fetchJobs(search: query);
      final selectedJobId = jobs.any((job) => job.id == state.selectedJobId)
          ? state.selectedJobId
          : jobs.isEmpty
          ? null
          : jobs.first.id;
      state = state.copyWith(
        jobs: jobs,
        isLoading: false,
        clearError: true,
        selectedJobId: selectedJobId,
        clearSelectedJob: jobs.isEmpty,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load project jobs. Pull to retry.',
      );
    }
  }

  Future<void> searchJobs(String query) => loadJobs(search: query);

  void selectJob(int jobId) {
    state = state.copyWith(selectedJobId: jobId, clearError: true);
  }

  void toggleMapTheme() {
    state = state.copyWith(isDarkMap: !state.isDarkMap);
  }

  void upsertJob(ProjectMapJob job) {
    final next = [...state.jobs];
    final index = next.indexWhere((item) => item.id == job.id);
    if (index >= 0) {
      next[index] = job;
    } else {
      next.add(job);
    }
    state = state.copyWith(jobs: next);
  }
}
