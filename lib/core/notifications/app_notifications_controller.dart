import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/notifications/app_notification_models.dart';
import 'package:red5/core/notifications/app_notifications_repository.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

final appNotificationsControllerProvider =
    StateNotifierProvider<AppNotificationsController, AppNotificationsState>((ref) {
      return AppNotificationsController(ref.read(appNotificationsRepositoryProvider));
    });

final class AppNotificationsController extends StateNotifier<AppNotificationsState> {
  AppNotificationsController(this._repository) : super(const AppNotificationsState());

  final AppNotificationsRepository _repository;
  Timer? _pollTimer;

  Future<void> initialize() async {
    final items = _repository.loadNotifications();
    state = state.copyWith(items: items, isInitialized: true);
  }

  void startPolling(Future<void> Function() onPoll) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(onPoll());
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> clearForLogout() async {
    stopPolling();
    await _repository.clearAll();
    state = const AppNotificationsState();
  }

  Future<void> processAssignedJobs(
    List<EmployeeJobSummary> jobs, {
    bool showInstantBanner = true,
  }) async {
    if (!state.isInitialized) {
      await initialize();
    }

    final currentIds = jobs.map((job) => job.id).toSet();
    final knownIds = _repository.loadKnownAssignedJobIds();
    final bootstrapped = _repository.isAssignmentTrackingBootstrapped();

    if (!bootstrapped) {
      await _repository.saveKnownAssignedJobIds(currentIds);
      await _repository.markAssignmentTrackingBootstrapped();
      return;
    }

    final newlyAssigned =
        jobs.where((job) => !knownIds.contains(job.id)).toList(growable: false);
    if (newlyAssigned.isEmpty) {
      await _repository.saveKnownAssignedJobIds(knownIds.union(currentIds));
      return;
    }

    final created = newlyAssigned
        .map(AppNotification.jobAssigned)
        .toList(growable: false);
    final updated = [...created, ...state.items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    state = state.copyWith(items: updated);
    await _repository.saveNotifications(updated);
    await _repository.saveKnownAssignedJobIds(knownIds.union(currentIds));

    if (showInstantBanner && created.isNotEmpty) {
      final latest = created.first;
      tryShowAppTopToast(
        title: latest.title,
        subtitle: latest.body,
        type: AppTopToastType.info,
      );
    }
  }

  Future<void> markRead(String id) async {
    final updated = state.items
        .map(
          (item) => item.id == id ? item.copyWith(isRead: true) : item,
        )
        .toList(growable: false);
    state = state.copyWith(items: updated);
    await _repository.saveNotifications(updated);
  }

  Future<void> markAllRead() async {
    final updated = state.items
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: false);
    state = state.copyWith(items: updated);
    await _repository.saveNotifications(updated);
  }
}
