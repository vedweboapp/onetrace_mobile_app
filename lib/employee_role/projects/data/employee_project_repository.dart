import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/quote/data/project_read.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

final employeeProjectRepositoryProvider = Provider<EmployeeProjectRepository>((
  ref,
) {
  return EmployeeProjectRepository(sl<QuoteProjectApiClient>());
});

final class EmployeeProjectRepository {
  EmployeeProjectRepository(this._api);

  final QuoteProjectApiClient _api;
  static final _dateFormat = DateFormat('MMM d, yyyy');

  Future<List<EmployeeProjectSummary>> fetchProjects() async {
    final rows = await _api.fetchAllProjects();
    final allJobs = await _api.fetchAllJobs();
    final jobsByProject = <int, List<JobRead>>{};
    for (final job in allJobs) {
      final projectId = job.project;
      if (projectId == null) continue;
      jobsByProject.putIfAbsent(projectId, () => <JobRead>[]).add(job);
    }
    return rows
        .map(
          (project) => _mapSummary(
            project,
            jobsByProject[project.id] ?? const <JobRead>[],
          ),
        )
        .toList(growable: false);
  }

  Future<EmployeeProjectDetail> fetchProjectDetail({
    int? projectId,
    String? projectName,
  }) async {
    ProjectRead? project;
    if (projectId != null) {
      project = await _api.fetchProjectById(projectId.toString());
    } else if (projectName != null && projectName.trim().isNotEmpty) {
      final all = await _api.fetchAllProjects();
      final normalized = projectName.trim().toLowerCase();
      for (final row in all) {
        if (row.name.toLowerCase() == normalized) {
          project = row;
          break;
        }
      }
      if (project == null) {
        final partial = all
            .where((row) => row.name.toLowerCase().contains(normalized))
            .toList(growable: false);
        if (partial.isNotEmpty) project = partial.first;
      }
      project ??= all.isEmpty ? null : all.first;
      if (project == null) {
        throw StateError('Project not found');
      }
    } else {
      throw ArgumentError('projectId or projectName is required');
    }

    final jobs = await _fetchJobsForProject(project.id);
    return _mapDetail(project, jobs);
  }

  Future<List<JobRead>> _fetchJobsForProject(int projectId) async {
    final allJobs = await _api.fetchAllJobs();
    return allJobs
        .where((job) => job.project == projectId)
        .toList(growable: false);
  }

  EmployeeProjectSummary _mapSummary(
    ProjectRead project,
    List<JobRead> jobs,
  ) {
    final completed = project.isCompleted;
    return EmployeeProjectSummary(
      id: project.id,
      title: project.name,
      status: completed ? 'COMPLETED' : 'ACTIVE',
      dueDate: _formatDate(project.endDate) ?? '—',
      client: project.clientName ?? 'Client',
      site: project.primarySiteName,
      activeSites: project.sites.where((s) => s.isActive).length,
      isCompleted: completed,
      jobCount: jobs.length,
      address: _formatProjectAddress(project),
      cardStatus: _deriveCardStatus(project, jobs),
    );
  }

  String _formatProjectAddress(ProjectRead project) {
    if (project.sites.isEmpty) return project.primarySiteName;
    final site = project.sites.first;
    final parts = [
      site.addressLine1,
      site.addressLine2,
      site.city,
      site.state,
      site.postalCode,
    ].where((part) => part.trim().isNotEmpty);
    final address = parts.join(', ');
    return address.isNotEmpty ? address : site.siteName;
  }

  EmployeeProjectCardStatus _deriveCardStatus(
    ProjectRead project,
    List<JobRead> jobs,
  ) {
    if (project.isCompleted) return EmployeeProjectCardStatus.review;
    final hasInProgress = jobs.any((job) {
      if (job.completedAt != null) return false;
      final status = job.displayStatus.toUpperCase();
      return status.contains('PROGRESS') || status.contains('ACTIVE');
    });
    if (hasInProgress) return EmployeeProjectCardStatus.inProgress;
    if (jobs.isEmpty) {
      return project.isActive
          ? EmployeeProjectCardStatus.scheduled
          : EmployeeProjectCardStatus.review;
    }
    final allCompleted = jobs.every((job) => job.completedAt != null);
    if (allCompleted) return EmployeeProjectCardStatus.review;
    return EmployeeProjectCardStatus.scheduled;
  }

  EmployeeProjectDetail _mapDetail(ProjectRead project, List<JobRead> jobs) {
    final completed = project.isCompleted;
    return EmployeeProjectDetail(
      id: project.id,
      title: project.name,
      status: completed ? 'PROJECT COMPLETED' : 'PROJECT ACTIVE',
      projectName: project.name,
      clientName: project.clientName ?? 'Client',
      siteName: project.primarySiteName,
      description: project.description?.trim().isNotEmpty == true
          ? project.description!.trim()
          : 'No description provided.',
      startDate: _formatDate(project.startDate) ?? '—',
      endDate: _formatDate(project.endDate) ?? '—',
      formIds: project.formIds,
      activeSites: project.sites.where((s) => s.isActive).length,
      isCompleted: completed,
      jobs: jobs.map(_mapJob).toList(growable: false),
    );
  }

  EmployeeProjectJobItem _mapJob(JobRead job) {
    final status = job.displayStatus.toUpperCase();
    final inProgress = status.contains('PROGRESS') || status.contains('ACTIVE');
    return EmployeeProjectJobItem(
      id: job.id,
      title: job.title,
      status: status,
      earning: job.total == null ? '—' : '£ ${job.total!.toStringAsFixed(2)}',
      location: job.displayLocation,
      schedule: _formatJobSchedule(job),
      actionLabel: inProgress
          ? 'Continue Job'
          : status.contains('COMPLETE')
          ? 'View Details'
          : 'Start Job',
    );
  }

  String _formatJobSchedule(JobRead job) {
    final start = _formatDate(job.startDate);
    final end = _formatDate(job.endDate);
    if (start == null && end == null) return 'Schedule TBD';
    if (start != null && end != null) return '$start - $end';
    return start ?? end ?? 'Schedule TBD';
  }

  String? _formatDate(DateTime? value) {
    if (value == null) return null;
    return _dateFormat.format(value);
  }
}
