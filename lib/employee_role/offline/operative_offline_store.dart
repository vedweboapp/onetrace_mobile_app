import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/database/technician_form_database.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/employee_role/offline/operative_sync_models.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

final operativeOfflineStoreProvider = Provider<OperativeOfflineStore>((ref) {
  return OperativeOfflineStore(sl<TechnicianFormDatabase>());
});

/// Local SQLite cache for operative jobs (list + detail).
final class OperativeOfflineStore {
  OperativeOfflineStore(this._database);

  final TechnicianFormDatabase _database;

  Future<void> cacheJobList(Iterable<JobRead> jobs) async {
    final payload = jsonEncode(
      jobs.map((job) => job.raw).toList(growable: false),
    );
    await _database.saveJobListCache(payload);
  }

  Future<List<JobRead>> readCachedJobList() async {
    final raw = await _database.readJobListCache();
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((entry) {
            if (entry is! Map) return null;
            return JobRead.tryFromMap(
              Map<String, dynamic>.from(
                entry.map((key, value) => MapEntry(key.toString(), value)),
              ),
            );
          })
          .whereType<JobRead>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> cacheJobDetail(JobRead job) async {
    await _database.saveJobDetailCache(
      jobId: job.id,
      jobJson: jsonEncode(job.raw),
    );
  }

  Future<JobRead?> readCachedJobDetail(int jobId) async {
    final raw = await _database.readJobDetailCache(jobId);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return JobRead.tryFromMap(
        Map<String, dynamic>.from(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> pendingSyncCount() => _database.countPendingSyncItems();
}

final operativeSyncQueueProvider = Provider<OperativeSyncQueue>((ref) {
  return OperativeSyncQueue(sl<TechnicianFormDatabase>());
});

/// Outbox for operative mutations made while offline.
final class OperativeSyncQueue {
  OperativeSyncQueue(this._database);

  final TechnicianFormDatabase _database;

  Future<void> enqueue({
    required OperativeSyncOperationType type,
    required Map<String, dynamic> payload,
    String? id,
  }) async {
    final queueId = id ?? _buildId(type, payload);
    await _database.enqueueSyncOperation(
      id: queueId,
      operationType: type.storageKey,
      payloadJson: jsonEncode(payload),
    );
  }

  Future<List<OperativeSyncQueueItem>> listPending() async {
    final rows = await _database.listSyncQueue();
    return rows.map(OperativeSyncQueueItem.fromDbRow).toList(growable: false);
  }

  Future<void> remove(String id) => _database.deleteSyncQueueItem(id);

  Future<void> recordFailure({
    required String id,
    required String error,
  }) =>
      _database.updateSyncQueueError(id: id, error: error);

  String _buildId(OperativeSyncOperationType type, Map<String, dynamic> payload) {
    final jobId = payload['jobId'];
    final qr = payload['qrCode'];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${type.storageKey}_${jobId ?? qr ?? 'x'}_$stamp';
  }
}
