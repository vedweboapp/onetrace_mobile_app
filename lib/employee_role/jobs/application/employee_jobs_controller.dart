import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
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
    this.selectedCalendarDate,
    this.selectedSiteName,
    this.selectedProjectName,
    this.filterDateRangeStart,
    this.filterDateRangeEnd,
  });

  final List<EmployeeJobSummary> jobs;
  final bool isLoading;
  final String? errorMessage;
  final EmployeeJobsFilter filter;
  final DateTime? selectedCalendarDate;
  final String? selectedSiteName;
  final String? selectedProjectName;
  final DateTime? filterDateRangeStart;
  final DateTime? filterDateRangeEnd;

  bool get hasDateRangeFilter =>
      filterDateRangeStart != null && filterDateRangeEnd != null;

  DateTime get effectiveSelectedDate {
    final selected = selectedCalendarDate;
    if (selected != null) return _dateOnly(selected);
    return _dateOnly(DateTime.now());
  }

  static bool _isActiveJob(EmployeeJobSummary job) =>
      job.status != EmployeeJobStatus.completed;

  List<EmployeeJobSummary> applyDateRangeFilter(
    List<EmployeeJobSummary> source,
  ) {
    final start = filterDateRangeStart;
    final end = filterDateRangeEnd;
    if (start == null || end == null) return source;

    final rangeStart = _dateOnly(start);
    final rangeEnd = _dateOnly(end);
    return source
        .where((job) {
          final jobDate = job.startDate;
          if (jobDate == null) return false;
          final day = _dateOnly(jobDate);
          return !day.isBefore(rangeStart) && !day.isAfter(rangeEnd);
        })
        .toList(growable: false);
  }

  List<EmployeeJobSummary> applyListFilters(List<EmployeeJobSummary> source) {
    return applyDateRangeFilter(applyLocationFilters(source));
  }

  List<EmployeeJobSummary> applyLocationFilters(
    List<EmployeeJobSummary> source,
  ) {
    final site = selectedSiteName?.trim();
    final project = selectedProjectName?.trim();
    if ((site == null || site.isEmpty) && (project == null || project.isEmpty)) {
      return source;
    }
    return source
        .where((job) {
          if (site != null &&
              site.isNotEmpty &&
              (job.siteName?.trim() ?? '') != site) {
            return false;
          }
          if (project != null &&
              project.isNotEmpty &&
              (job.projectName?.trim() ?? '') != project) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<String> get availableSiteNames {
    final source = selectedProjectName == null
        ? jobs
        : jobs.where((job) => job.projectName == selectedProjectName);
    return _uniqueNames(source.map((job) => job.siteName));
  }

  List<String> get availableProjectNames {
    final source = selectedSiteName == null
        ? jobs
        : jobs.where((job) => job.siteName == selectedSiteName);
    return _uniqueNames(source.map((job) => job.projectName));
  }

  Set<DateTime> get jobDates {
    return applyLocationFilters(jobs)
        .where(_isActiveJob)
        .map((job) => job.startDate)
        .whereType<DateTime>()
        .map(_dateOnly)
        .toSet();
  }

  List<EmployeeJobSummary> jobsForDate(DateTime date) {
    final target = _dateOnly(date);
    return applyLocationFilters(jobs)
        .where(
          (job) =>
              _isActiveJob(job) &&
              job.startDate != null &&
              _dateOnly(job.startDate!) == target,
        )
        .toList(growable: false);
  }

  List<EmployeeJobSummary> get selectedDateJobs =>
      jobsForDate(effectiveSelectedDate);

  List<EmployeeJobSummary> get weekJobs {
    final anchor = effectiveSelectedDate;
    final daysFromSunday = anchor.weekday % 7;
    final weekStart = anchor.subtract(Duration(days: daysFromSunday));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return applyLocationFilters(jobs)
        .where((job) {
          if (!_isActiveJob(job)) return false;
          final start = job.startDate;
          if (start == null) return false;
          final day = _dateOnly(start);
          return !day.isBefore(weekStart) && !day.isAfter(weekEnd);
        })
        .toList(growable: false)
      ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  }

  List<EmployeeJobSummary> visibleJobsFor(EmployeeJobSessionController session) {
    final resolved = jobs.map(session.withLocalProgress).toList(growable: false);
    final filtered = applyListFilters(resolved);
    return switch (filter) {
      EmployeeJobsFilter.all =>
        filtered.where(_isActiveJob).toList(growable: false),
      EmployeeJobsFilter.inProgress => filtered
          .where((job) => job.status == EmployeeJobStatus.inProgress)
          .toList(growable: false),
      EmployeeJobsFilter.upcoming => filtered
          .where((job) => job.status == EmployeeJobStatus.upcoming)
          .toList(growable: false),
      EmployeeJobsFilter.completed => filtered
          .where((job) => job.status == EmployeeJobStatus.completed)
          .toList(growable: false),
    };
  }

  List<EmployeeJobSummary> selectedDateJobsFor(
    EmployeeJobSessionController session,
  ) {
    return jobsForDate(effectiveSelectedDate)
        .map(session.withLocalProgress)
        .toList(growable: false);
  }

  List<EmployeeJobSummary> weekJobsFor(EmployeeJobSessionController session) {
    return weekJobs.map(session.withLocalProgress).toList(growable: false);
  }

  List<EmployeeJobSummary> get visibleJobs {
    final filtered = applyListFilters(jobs);
    return switch (filter) {
      EmployeeJobsFilter.all =>
        filtered.where(_isActiveJob).toList(growable: false),
      EmployeeJobsFilter.inProgress =>
        filtered
            .where((job) => job.status == EmployeeJobStatus.inProgress)
            .toList(growable: false),
      EmployeeJobsFilter.upcoming =>
        filtered
            .where((job) => job.status == EmployeeJobStatus.upcoming)
            .toList(growable: false),
      EmployeeJobsFilter.completed =>
        filtered
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
    DateTime? selectedCalendarDate,
    bool clearSelectedCalendarDate = false,
    String? selectedSiteName,
    bool clearSelectedSiteName = false,
    String? selectedProjectName,
    bool clearSelectedProjectName = false,
    DateTime? filterDateRangeStart,
    DateTime? filterDateRangeEnd,
    bool clearFilterDateRange = false,
  }) {
    return EmployeeJobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      filter: filter ?? this.filter,
      selectedCalendarDate: clearSelectedCalendarDate
          ? null
          : selectedCalendarDate ?? this.selectedCalendarDate,
      selectedSiteName: clearSelectedSiteName
          ? null
          : selectedSiteName ?? this.selectedSiteName,
      selectedProjectName: clearSelectedProjectName
          ? null
          : selectedProjectName ?? this.selectedProjectName,
      filterDateRangeStart: clearFilterDateRange
          ? null
          : filterDateRangeStart ?? this.filterDateRangeStart,
      filterDateRangeEnd: clearFilterDateRange
          ? null
          : filterDateRangeEnd ?? this.filterDateRangeEnd,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static List<String> _uniqueNames(Iterable<String?> values) {
    final names = values
        .map((value) => value?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return names;
  }
}

final class EmployeeJobsController extends StateNotifier<EmployeeJobsState> {
  EmployeeJobsController(this._repository) : super(const EmployeeJobsState());

  final EmployeeJobRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final jobs = await _repository.fetchJobs();
      state = _stateWithValidFilters(
        state.copyWith(jobs: jobs, isLoading: false, clearError: true),
      );
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

  void setSiteFilter(String? siteName) {
    final normalized = siteName?.trim();
    var project = state.selectedProjectName;
    if (normalized != null && normalized.isNotEmpty && project != null) {
      final projectsAtSite = EmployeeJobsState._uniqueNames(
        state.jobs
            .where((job) => job.siteName?.trim() == normalized)
            .map((job) => job.projectName),
      );
      if (!projectsAtSite.contains(project)) {
        project = null;
      }
    }
    state = state.copyWith(
      selectedSiteName: normalized,
      clearSelectedSiteName: normalized == null || normalized.isEmpty,
      selectedProjectName: project,
      clearSelectedProjectName: project == null,
    );
  }

  void setProjectFilter(String? projectName) {
    final normalized = projectName?.trim();
    var site = state.selectedSiteName;
    if (normalized != null && normalized.isNotEmpty && site != null) {
      final sitesForProject = EmployeeJobsState._uniqueNames(
        state.jobs
            .where((job) => job.projectName?.trim() == normalized)
            .map((job) => job.siteName),
      );
      if (!sitesForProject.contains(site)) {
        site = null;
      }
    }
    state = state.copyWith(
      selectedProjectName: normalized,
      clearSelectedProjectName: normalized == null || normalized.isEmpty,
      selectedSiteName: site,
      clearSelectedSiteName: site == null,
    );
  }

  void selectCalendarDate(DateTime date) {
    state = state.copyWith(
      selectedCalendarDate: EmployeeJobsState._dateOnly(date),
    );
  }

  void setDateRange({required DateTime start, required DateTime end}) {
    final rangeStart = EmployeeJobsState._dateOnly(start);
    var rangeEnd = EmployeeJobsState._dateOnly(end);
    if (rangeEnd.isBefore(rangeStart)) {
      rangeEnd = rangeStart;
    }
    state = state.copyWith(
      filterDateRangeStart: rangeStart,
      filterDateRangeEnd: rangeEnd,
    );
  }

  void clearDateRange() {
    state = state.copyWith(clearFilterDateRange: true);
  }

  EmployeeJobsState _stateWithValidFilters(EmployeeJobsState next) {
    var site = next.selectedSiteName;
    var project = next.selectedProjectName;
    if (site != null && !next.availableSiteNames.contains(site)) {
      site = null;
    }
    if (project != null && !next.availableProjectNames.contains(project)) {
      project = null;
    }
    return next.copyWith(
      selectedSiteName: site,
      clearSelectedSiteName: site == null,
      selectedProjectName: project,
      clearSelectedProjectName: project == null,
    );
  }
}
