import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/notifications/app_notifications_repository.dart';
import 'package:red5/core/notifications/data/notification_models.dart';
import 'package:red5/core/notifications/data/notifications_api_client.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/offline/operative_cache_policy.dart';

final appNotificationsControllerProvider =
    StateNotifierProvider<AppNotificationsController, AppNotificationsState>((
      ref,
    ) {
      return AppNotificationsController(
        api: ref.read(notificationsApiClientProvider),
        repository: ref.read(appNotificationsRepositoryProvider),
      );
    });

final class AppNotificationsState {
  const AppNotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isInitialized = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isMarkingAll = false,
    this.errorMessage,
    this.nextCursor,
  });

  final List<AppNotificationItem> items;
  final int unreadCount;
  final bool isInitialized;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isMarkingAll;
  final String? errorMessage;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.trim().isNotEmpty;

  AppNotificationsState copyWith({
    List<AppNotificationItem>? items,
    int? unreadCount,
    bool? isInitialized,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isMarkingAll,
    String? errorMessage,
    bool clearError = false,
    String? nextCursor,
    bool clearCursor = false,
  }) {
    return AppNotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMarkingAll: isMarkingAll ?? this.isMarkingAll,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    );
  }
}

final class AppNotificationsController
    extends StateNotifier<AppNotificationsState> {
  AppNotificationsController({
    required NotificationsApiClient api,
    required AppNotificationsRepository repository,
  }) : _api = api,
       _repository = repository,
       super(const AppNotificationsState());

  final NotificationsApiClient _api;
  final AppNotificationsRepository _repository;
  Timer? _pollTimer;
  bool _refreshInFlight = false;

  Future<void> initialize() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _api.fetchNotifications();
      final unread = await _safeUnreadCount(fallback: _countUnread(page.items));
      if (!mounted) return;
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: !page.hasMore,
        unreadCount: unread,
        isInitialized: true,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        errorMessage: ApiResponseMessage.fromAnyError(e),
      );
    }
  }

  Future<void> refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final page = await _api.fetchNotifications();
      final unread = await _safeUnreadCount(fallback: _countUnread(page.items));
      if (!mounted) return;
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: !page.hasMore,
        unreadCount: unread,
        isInitialized: true,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (!mounted) return;
      // Keep existing items; surface error only when the list is empty.
      if (state.items.isEmpty) {
        state = state.copyWith(
          errorMessage: ApiResponseMessage.fromAnyError(e),
          isLoading: false,
        );
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final unread = await _api.fetchUnreadCount();
      if (!mounted) return;
      state = state.copyWith(unreadCount: unread);
    } catch (_) {
      // Badge stays on last known value.
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _api.fetchNotifications(cursor: cursor);
      if (!mounted) return;
      final merged = _mergeById([...state.items, ...page.items]);
      state = state.copyWith(
        items: merged,
        nextCursor: page.nextCursor,
        clearCursor: !page.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void startPolling(Future<void> Function() onPoll) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      OperativeCachePolicy.notificationPollInterval,
      (_) {
        unawaited(onPoll());
        unawaited(refreshUnreadCount());
      },
    );
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

  /// Local toast when newly assigned jobs appear; server owns the inbox list.
  Future<void> processAssignedJobs(
    List<EmployeeJobSummary> jobs, {
    bool showInstantBanner = true,
  }) async {
    final currentIds = jobs.map((job) => job.id).toSet();
    final knownIds = _repository.loadKnownAssignedJobIds();
    final bootstrapped = _repository.isAssignmentTrackingBootstrapped();

    if (!bootstrapped) {
      await _repository.saveKnownAssignedJobIds(currentIds);
      await _repository.markAssignmentTrackingBootstrapped();
      return;
    }

    final newlyAssigned = jobs
        .where((job) => !knownIds.contains(job.id))
        .toList(growable: false);
    await _repository.saveKnownAssignedJobIds(knownIds.union(currentIds));

    if (newlyAssigned.isEmpty) return;

    if (showInstantBanner) {
      final job = newlyAssigned.first;
      tryShowAppTopToast(
        title: 'New Job Assigned',
        subtitle: 'You were assigned "${job.title}".',
        type: AppTopToastType.info,
      );
    }
    unawaited(refresh());
  }

  Future<void> markRead(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;

    final before = state.items;
    final updated = before
        .map((item) => item.id == trimmed ? item.copyWith(isRead: true) : item)
        .toList(growable: false);
    final wasUnread = before.any((item) => item.id == trimmed && !item.isRead);
    state = state.copyWith(
      items: updated,
      unreadCount: wasUnread
          ? (state.unreadCount > 0 ? state.unreadCount - 1 : 0)
          : state.unreadCount,
    );

    try {
      await _api.markRead(trimmed);
      unawaited(refreshUnreadCount());
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        items: before,
        unreadCount: wasUnread ? state.unreadCount + 1 : state.unreadCount,
      );
      tryShowAppTopToast(
        title: 'Could not mark as read',
        subtitle: ApiResponseMessage.fromAnyError(e),
        type: AppTopToastType.error,
      );
    }
  }

  Future<void> markAllRead() async {
    if (state.isMarkingAll) return;
    final unreadIds = state.items
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toList(growable: false);
    if (unreadIds.isEmpty) {
      state = state.copyWith(unreadCount: 0);
      return;
    }

    final before = state.items;
    final beforeCount = state.unreadCount;
    state = state.copyWith(
      isMarkingAll: true,
      items: before
          .map((item) => item.copyWith(isRead: true))
          .toList(growable: false),
      unreadCount: 0,
    );

    try {
      await _api.markAllRead(unreadIds);
      if (!mounted) return;
      state = state.copyWith(isMarkingAll: false);
      unawaited(refreshUnreadCount());
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isMarkingAll: false,
        items: before,
        unreadCount: beforeCount,
      );
      tryShowAppTopToast(
        title: 'Could not mark all as read',
        subtitle: ApiResponseMessage.fromAnyError(e),
        type: AppTopToastType.error,
      );
    }
  }

  Future<int> _safeUnreadCount({required int fallback}) async {
    try {
      return await _api.fetchUnreadCount();
    } catch (_) {
      return fallback;
    }
  }

  static int _countUnread(List<AppNotificationItem> items) =>
      items.where((item) => !item.isRead).length;

  static List<AppNotificationItem> _mergeById(List<AppNotificationItem> items) {
    final seen = <String>{};
    final out = <AppNotificationItem>[];
    for (final item in items) {
      if (!seen.add(item.id)) continue;
      out.add(item);
    }
    return out;
  }


  // future<void>
}

 