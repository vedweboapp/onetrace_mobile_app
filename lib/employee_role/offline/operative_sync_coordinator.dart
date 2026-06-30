import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/offline/operative_offline_store.dart';
import 'package:red5/employee_role/offline/operative_sync_models.dart';
import 'package:red5/employee_role/offline/operative_sync_processor.dart';

final operativeSyncCoordinatorProvider =
    Provider<OperativeSyncCoordinator>((ref) {
  final coordinator = OperativeSyncCoordinator(
    connectivity: ref.read(connectivityServiceProvider),
    offlineStore: ref.read(operativeOfflineStoreProvider),
    processor: ref.read(operativeSyncProcessorProvider),
    submissionRepository: ref.read(jobFormSubmissionRepositoryProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Starts background sync when the device comes back online.
final operativeSyncBootstrapProvider = Provider<void>((ref) {
  final coordinator = ref.watch(operativeSyncCoordinatorProvider);
  coordinator.ensureListening();
});

final operativePendingSyncCountProvider =
    StreamProvider.autoDispose<int>((ref) {
  final coordinator = ref.watch(operativeSyncCoordinatorProvider);
  return coordinator.pendingCountStream;
});

final class OperativeSyncCoordinator {
  OperativeSyncCoordinator({
    required ConnectivityService connectivity,
    required OperativeOfflineStore offlineStore,
    required OperativeSyncProcessor processor,
    required JobFormSubmissionRepository submissionRepository,
  })  : _connectivity = connectivity,
        _offlineStore = offlineStore,
        _processor = processor,
        _submissionRepository = submissionRepository;

  final ConnectivityService _connectivity;
  final OperativeOfflineStore _offlineStore;
  final OperativeSyncProcessor _processor;
  final JobFormSubmissionRepository _submissionRepository;

  StreamSubscription<bool>? _subscription;
  var _listening = false;
  var _syncInFlight = false;
  final _pendingCountController = StreamController<int>.broadcast();

  Stream<int> get pendingCountStream => _pendingCountController.stream;

  void ensureListening() {
    if (_listening) return;
    _listening = true;
    unawaited(_emitPendingCount());
    _subscription = _connectivity.isOnlineStream.listen((online) async {
      if (!online) return;
      await syncAll();
    });
    if (_connectivity.isOnline) {
      unawaited(syncAll());
    }
  }

  Future<OperativeSyncResult> syncAll() async {
    if (!_connectivity.isOnline) {
      return const OperativeSyncResult(skippedOffline: true);
    }
    if (_syncInFlight) return const OperativeSyncResult();
    _syncInFlight = true;
    try {
      final formsSynced = await _submissionRepository.syncPendingSubmissions();
      final queueProcessed = await _processor.processQueue();
      await _emitPendingCount();
      return OperativeSyncResult(
        formsSynced: formsSynced,
        queueProcessed: queueProcessed,
      );
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> _emitPendingCount() async {
    final count = await _offlineStore.pendingSyncCount();
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(count);
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_pendingCountController.close());
  }
}
