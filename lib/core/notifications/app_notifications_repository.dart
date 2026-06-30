import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/notifications/app_notification_models.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';

final appNotificationsRepositoryProvider = Provider<AppNotificationsRepository>(
  (ref) => AppNotificationsRepository(ref.read(localStorageProvider)),
);

class AppNotificationsRepository {
  AppNotificationsRepository(this._storage);

  final LocalStorage _storage;

  List<AppNotification> loadNotifications() {
    final raw = _storage.getString(LocalStorageKeys.appNotifications);
    final items = AppNotification.listFromJsonString(raw);
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveNotifications(List<AppNotification> items) async {
    await _storage.setString(
      LocalStorageKeys.appNotifications,
      AppNotification.listToJsonString(items),
    );
  }

  Set<int> loadKnownAssignedJobIds() {
    final raw = _storage.getString(LocalStorageKeys.appKnownAssignedJobIds);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded
          .map((value) => value is int ? value : int.tryParse('$value'))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveKnownAssignedJobIds(Set<int> ids) async {
    await _storage.setString(
      LocalStorageKeys.appKnownAssignedJobIds,
      jsonEncode(ids.toList(growable: false)..sort()),
    );
  }

  bool isAssignmentTrackingBootstrapped() {
    return _storage.getBool(LocalStorageKeys.appAssignmentTrackingReady) ?? false;
  }

  Future<void> markAssignmentTrackingBootstrapped() async {
    await _storage.setBool(LocalStorageKeys.appAssignmentTrackingReady, true);
  }

  Future<void> clearAll() async {
    await _storage.remove(LocalStorageKeys.appNotifications);
    await _storage.remove(LocalStorageKeys.appKnownAssignedJobIds);
    await _storage.remove(LocalStorageKeys.appAssignmentTrackingReady);
  }
}
