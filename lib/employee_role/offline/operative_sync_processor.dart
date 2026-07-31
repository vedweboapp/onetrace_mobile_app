import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/data/job_qr_scan_repository.dart';
import 'package:red5/employee_role/offline/operative_offline_store.dart';
import 'package:red5/employee_role/offline/operative_sync_models.dart';

final operativeSyncProcessorProvider = Provider<OperativeSyncProcessor>((ref) {
  return OperativeSyncProcessor(
    queue: ref.read(operativeSyncQueueProvider),
    jobRepository: ref.read(employeeJobRepositoryProvider),
    qrScanRepository: ref.read(jobQrScanRepositoryProvider),
  );
});

/// Drains the operative outbox when connectivity is restored.
final class OperativeSyncProcessor {
  OperativeSyncProcessor({
    required OperativeSyncQueue queue,
    required EmployeeJobRepository jobRepository,
    required JobQrScanRepository qrScanRepository,
  }) : _queue = queue,
       _jobRepository = jobRepository,
       _qrScanRepository = qrScanRepository;

  final OperativeSyncQueue _queue;
  final EmployeeJobRepository _jobRepository;
  final JobQrScanRepository _qrScanRepository;

  Future<int> processQueue() async {
    final pending = await _queue.listPending();
    var processed = 0;

    for (final item in pending) {
      try {
        await _processItem(item);
        await _queue.remove(item.id);
        processed++;
      } catch (error) {
        await _queue.recordFailure(id: item.id, error: error.toString());
      }
    }

    return processed;
  }

  Future<void> _processItem(OperativeSyncQueueItem item) async {
    switch (item.operationType) {
      case OperativeSyncOperationType.jobStarted:
        final jobId = _readJobId(item.payload);
        if (jobId == null) return;
        await _jobRepository.markJobStarted(jobId, fromSync: true);
      case OperativeSyncOperationType.jobCompleted:
        final jobId = _readJobId(item.payload);
        if (jobId == null) return;
        await _jobRepository.markJobCompleted(jobId, fromSync: true);
      case OperativeSyncOperationType.jobChecklistUpdate:
        final jobId = _readJobId(item.payload);
        final items = item.payload['items'];
        if (jobId == null || items is! List) return;
        await _jobRepository.updateJobChecklistsFromPayload(
          jobId: jobId,
          itemsPayload: items,
          fromSync: true,
        );
      case OperativeSyncOperationType.qrScan:
        final qrCode = item.payload['qrCode']?.toString().trim();
        if (qrCode == null || qrCode.isEmpty) return;
        final jobId = _readJobId(item.payload);
        final jobPinId = _readJobPinId(item.payload);
        await _qrScanRepository.processScan(
          qrCode: qrCode,
          jobId: jobId,
          jobPinId: jobPinId,
          fromSync: true,
        );
    }
  }

  int? _readJobId(Map<String, dynamic> payload) {
    final raw = payload['jobId'];
    if (raw is int) return raw;
    if (raw != null) return int.tryParse(raw.toString());
    return null;
  }

  int? _readJobPinId(Map<String, dynamic> payload) {
    final raw = payload['jobPinId'];
    if (raw is int) return raw;
    if (raw != null) return int.tryParse(raw.toString());
    return null;
  }
}
