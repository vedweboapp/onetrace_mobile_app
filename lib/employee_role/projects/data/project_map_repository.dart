import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/employee_role/jobs/data/assigned_jobs_filter.dart';
import 'package:red5/employee_role/projects/data/project_map_job.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

final projectMapRepositoryProvider = Provider<ProjectMapRepository>((ref) {
  return ProjectMapRepository(
    sl<QuoteProjectApiClient>(),
    sl<LocalStorage>(),
  );
});

final class ProjectMapRepository {
  ProjectMapRepository(this._api, this._storage);

  final QuoteProjectApiClient _api;
  final LocalStorage _storage;

  Future<List<ProjectMapJob>> fetchJobs({
    int? projectId,
    String? search,
  }) async {
    if (projectId == null) return const [];

    final project = await _api.fetchProjectById(projectId.toString());
    final allJobs = await AssignedJobsFilter.fetchAssignedJobs(
      storage: _storage,
      fetchAll: ({assignedWorker}) =>
          _api.fetchAllJobs(assignedWorker: assignedWorker),
    );
    final projectJobs = allJobs
        .where((job) => job.project == projectId)
        .map(ProjectMapJob.fromJobRead)
        .whereType<ProjectMapJob>()
        .toList(growable: false);

    final items = projectJobs.isNotEmpty
        ? projectJobs
        : project.sites
              .where((site) => site.isActive)
              .map(ProjectMapJob.fromSite)
              .toList(growable: false);

    final query = search?.trim().toLowerCase();
    if (query == null || query.isEmpty) return items;

    return items
        .where((job) {
          return job.title.toLowerCase().contains(query) ||
              job.address.toLowerCase().contains(query) ||
              job.status.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }
}
