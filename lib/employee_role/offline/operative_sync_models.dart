import 'dart:convert';

enum OperativeSyncOperationType {
  jobStarted('job_started'),
  jobCompleted('job_completed'),
  jobChecklistUpdate('job_checklist_update'),
  qrScan('qr_scan');

  const OperativeSyncOperationType(this.storageKey);

  final String storageKey;

  static OperativeSyncOperationType? fromStorageKey(String key) {
    for (final value in values) {
      if (value.storageKey == key) return value;
    }
    return null;
  }
}

final class OperativeSyncQueueItem {
  const OperativeSyncQueueItem({
    required this.id,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final OperativeSyncOperationType operationType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  factory OperativeSyncQueueItem.fromDbRow(Map<String, Object?> row) {
    final typeKey = row['operation_type'] as String? ?? '';
    final payloadRaw = row['payload_json'] as String? ?? '{}';
    Map<String, dynamic> payload = const {};
    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is Map) {
        payload = Map<String, dynamic>.from(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}
    return OperativeSyncQueueItem(
      id: row['id'] as String? ?? '',
      operationType:
          OperativeSyncOperationType.fromStorageKey(typeKey) ??
          OperativeSyncOperationType.qrScan,
      payload: payload,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
      ),
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error'] as String?,
    );
  }
}

final class OperativeSyncResult {
  const OperativeSyncResult({
    this.formsSynced = 0,
    this.queueProcessed = 0,
    this.skippedOffline = false,
  });

  final int formsSynced;
  final int queueProcessed;
  final bool skippedOffline;

  bool get didWork => formsSynced > 0 || queueProcessed > 0;
}

/// Thrown when an action was queued locally and will sync when online.
final class OperativeOfflineQueuedException implements Exception {
  const OperativeOfflineQueuedException(this.message);

  final String message;

  @override
  String toString() => message;
}
