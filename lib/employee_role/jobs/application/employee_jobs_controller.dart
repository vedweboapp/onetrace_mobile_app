import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';

final employeeJobsControllerProvider =
    StateNotifierProvider.autoDispose<
      EmployeeJobsController,
      EmployeeJobsState
    >((ref) => EmployeeJobsController(ref.read(employeeJobRepositoryProvider)));

enum EmployeeJobsFilter {
  all('All'),
  inProgress('In Progress'),
  upcoming('Upcoming'),
  completed('Completed');

  const EmployeeJobsFilter(this.label);

  final String label;
}

final class EmployeeJobsState {
  const EmployeeJobsState({
    this.jobs = const <EmployeeJobSummary>[],
    this.isLoading = false,
    this.errorMessage,
    this.filter = EmployeeJobsFilter.all,
  });

  final List<EmployeeJobSummary> jobs;
  final bool isLoading;
  final String? errorMessage;
  final EmployeeJobsFilter filter;

  List<EmployeeJobSummary> get visibleJobs {
    return switch (filter) {
      EmployeeJobsFilter.all => jobs,
      EmployeeJobsFilter.inProgress =>
        jobs
            .where((job) => job.status == EmployeeJobStatus.inProgress)
            .toList(growable: false),
      EmployeeJobsFilter.upcoming =>
        jobs
            .where((job) => job.status == EmployeeJobStatus.upcoming)
            .toList(growable: false),
      EmployeeJobsFilter.completed =>
        jobs
            .where((job) => job.status == EmployeeJobStatus.completed)
            .toList(growable: false),
    };
  }

  EmployeeJobsState copyWith({
    List<EmployeeJobSummary>? jobs,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    EmployeeJobsFilter? filter,
  }) {
    return EmployeeJobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      filter: filter ?? this.filter,
    );
  }
}

final class EmployeeJobsController extends StateNotifier<EmployeeJobsState> {
  EmployeeJobsController(this._repository) : super(const EmployeeJobsState());

  final EmployeeJobRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final jobs = await _repository.fetchJobs();
      state = state.copyWith(jobs: jobs, isLoading: false, clearError: true);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load jobs.',
      );
    }
  }

  void setFilter(EmployeeJobsFilter filter) {
    state = state.copyWith(filter: filter);
  }
}
