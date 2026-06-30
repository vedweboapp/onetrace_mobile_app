import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/employee_role/jobs/data/assigned_jobs_filter.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

class _MemoryStorage implements LocalStorage {
  final Map<String, Object> _data = {};

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _data[key] = value;

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  Future<void> setInt(String key, int value) async => _data[key] = value;
}

void main() {
  test('onlyAssignedToCurrentUser keeps matching assigned_worker rows', () async {
    final storage = _MemoryStorage();
    await storage.setString(LocalStorageKeys.authUserId, '7');

    final jobs = [
      JobRead(
        id: 1,
        title: 'Mine',
        assignedWorker: 7,
        jobMeta: const {},
        formIds: const [],
        raw: const {},
      ),
      JobRead(
        id: 2,
        title: 'Other',
        assignedWorker: 3,
        jobMeta: const {},
        formIds: const [],
        raw: const {},
      ),
    ];

    final filtered = AssignedJobsFilter.onlyAssignedToCurrentUser(
      jobs,
      storage: storage,
    );

    expect(filtered.map((job) => job.id), [1]);
  });

  test('onlyAssignedToCurrentUser returns empty when user id is missing', () {
    final storage = _MemoryStorage();
    final jobs = [
      JobRead(
        id: 1,
        title: 'Mine',
        assignedWorker: 7,
        jobMeta: const {},
        formIds: const [],
        raw: const {},
      ),
    ];

    expect(
      AssignedJobsFilter.onlyAssignedToCurrentUser(jobs, storage: storage),
      isEmpty,
    );
  });
}
