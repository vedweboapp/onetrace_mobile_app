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

    this.selectedCalendarDate,

  });



  final List<EmployeeJobSummary> jobs;

  final bool isLoading;

  final String? errorMessage;

  final EmployeeJobsFilter filter;

  final DateTime? selectedCalendarDate;



  DateTime get effectiveSelectedDate {

    final selected = selectedCalendarDate;

    if (selected != null) return _dateOnly(selected);

    return _dateOnly(DateTime.now());

  }



  Set<DateTime> get jobDates {

    return jobs

        .map((job) => job.startDate)

        .whereType<DateTime>()

        .map(_dateOnly)

        .toSet();

  }



  List<EmployeeJobSummary> jobsForDate(DateTime date) {

    final target = _dateOnly(date);

    return jobs

        .where(

          (job) =>

              job.startDate != null && _dateOnly(job.startDate!) == target,

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

    return jobs

        .where((job) {

          final start = job.startDate;

          if (start == null) return false;

          final day = _dateOnly(start);

          return !day.isBefore(weekStart) && !day.isAfter(weekEnd);

        })

        .toList(growable: false)

      ..sort((a, b) => a.startDate!.compareTo(b.startDate!));

  }



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

    DateTime? selectedCalendarDate,

    bool clearSelectedCalendarDate = false,

  }) {

    return EmployeeJobsState(

      jobs: jobs ?? this.jobs,

      isLoading: isLoading ?? this.isLoading,

      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,

      filter: filter ?? this.filter,

      selectedCalendarDate: clearSelectedCalendarDate

          ? null

          : selectedCalendarDate ?? this.selectedCalendarDate,

    );

  }



  static DateTime _dateOnly(DateTime value) {

    return DateTime(value.year, value.month, value.day);

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



  void selectCalendarDate(DateTime date) {

    state = state.copyWith(

      selectedCalendarDate: EmployeeJobsState._dateOnly(date),

    );

  }

}

