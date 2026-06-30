import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

/// Limits operative / technician / sales job lists to the signed-in worker.
abstract final class AssignedJobsFilter {
  const AssignedJobsFilter._();

  /// Logged-in user's profile id (`assigned_worker` FK on jobs).
  static String? currentWorkerId(LocalStorage storage) {
    final id = storage.getString(LocalStorageKeys.authUserId)?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Query param for `GET /jobs/?assigned_worker=`.
  static String? assignedWorkerQuery(LocalStorage storage) =>
      currentWorkerId(storage);

  /// Client-side guard when the API returns extra rows.
  static List<JobRead> onlyAssignedToCurrentUser(
    List<JobRead> jobs, {
    required LocalStorage storage,
  }) {
    final workerId = currentWorkerId(storage);
    if (workerId == null) return const [];

    final workerIdInt = int.tryParse(workerId);
    return jobs
        .where((job) {
          final assigned = job.assignedWorker;
          if (assigned == null) return false;
          if (workerIdInt != null) return assigned == workerIdInt;
          return assigned.toString() == workerId;
        })
        .toList(growable: false);
  }

  static Future<List<JobRead>> fetchAssignedJobs({
    required LocalStorage storage,
    required Future<List<JobRead>> Function({String? assignedWorker}) fetchAll,
  }) async {
    final workerId = assignedWorkerQuery(storage);
    if (workerId == null) return const [];

    final rows = await fetchAll(assignedWorker: workerId);
    return onlyAssignedToCurrentUser(rows, storage: storage);
  }
}
