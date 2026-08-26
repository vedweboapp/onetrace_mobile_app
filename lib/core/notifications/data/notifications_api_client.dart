import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/notifications/data/notification_models.dart';

/// HTTP client for `/api/v1/notifications/`.
final class NotificationsApiClient {
  NotificationsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `GET /notifications/` — cursor-paginated list.
  ///
  /// Pass [unreadOnly] to request `?type=unread`.
  Future<NotificationsPageResult> fetchNotifications({
    bool unreadOnly = false,
    String? cursor,
  }) async {
    final query = <String, dynamic>{
      if (unreadOnly) 'type': 'unread',
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.notifications,
      queryParameters: query.isEmpty ? null : query,
    );
    return _parseListResponse(response.data);
  }

  /// `GET /notifications/unread-count/`.
  Future<int> fetchUnreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.notificationsUnreadCount,
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _asMap(root['data']);
    final raw = data['unread_count'] ?? data['unreadCount'] ?? root['unread_count'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }

  /// `PATCH /notifications/{id}/mark-read/`.
  Future<void> markRead(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.notificationMarkRead(trimmed),
    );
  }

  /// Marks every unread item currently known (best-effort sequential PATCH).
  Future<void> markAllRead(Iterable<String> ids) async {
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      try {
        await markRead(trimmed);
      } catch (_) {
        // Continue marking remaining items.
      }
    }
  }

  static NotificationsPageResult _parseListResponse(Map<String, dynamic>? root) {
    final r = root ?? const <String, dynamic>{};
    final rows = _readRows(r);
    final items = rows
        .map(AppNotificationItem.fromJson)
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);

    final pagination = _asMap(r['pagination']);
    final nextRaw = pagination['next'];
    final nextCursor = _cursorFromNext(nextRaw);

    return NotificationsPageResult(items: items, nextCursor: nextCursor);
  }

  /// Extracts `cursor` from a full next URL or returns a bare cursor string.
  static String? _cursorFromNext(dynamic next) {
    if (next == null) return null;
    final s = next.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    final uri = Uri.tryParse(s);
    if (uri != null && uri.hasQuery) {
      final c = uri.queryParameters['cursor']?.trim();
      if (c != null && c.isNotEmpty) return c;
    }
    // Already a cursor token (not a URL).
    if (!s.startsWith('http')) return s;
    return null;
  }

  static List<Map<String, dynamic>> _readRows(Map<String, dynamic> root) {
    final raw = root['data'] ?? root['results'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (e) => Map<String, dynamic>.from(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const {};
  }
}

final notificationsApiClientProvider = Provider<NotificationsApiClient>(
  (ref) => sl<NotificationsApiClient>(),
);
