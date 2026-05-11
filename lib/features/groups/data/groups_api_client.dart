import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/groups/data/group_models.dart';

class GroupsPageResult {
  const GroupsPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<GroupModel> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

/// Payload row for a group's composite item entry.
class GroupItemDraft {
  GroupItemDraft({required this.compositeItemId, required this.abbreviation});

  final String compositeItemId;
  final String abbreviation;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'composite_item': compositeItemId,
    'composite_item_id': compositeItemId,
    'abbreviation': abbreviation,
  };
}

final class GroupsApiClient {
  GroupsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<GroupsPageResult> fetchGroupsPage({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.groups,
      queryParameters: <String, dynamic>{'page': page},
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = _readRows(root);
    final groups = rows.map(GroupModel.fromJson).toList();
    final pagination = _readMap(root['pagination']);
    final currentPage = _readInt(pagination, const ['current_page']) ?? page;
    final totalPages = _readInt(pagination, const ['total_pages']) ?? 1;
    final totalRecords =
        _readInt(pagination, const ['total_records']) ?? groups.length;
    return GroupsPageResult(
      items: groups,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalRecords: totalRecords < 0 ? 0 : totalRecords,
    );
  }

  Future<GroupModel> fetchGroupDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.groupById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return GroupModel.fromJson(payload);
  }

  Future<GroupModel> createGroup({
    required String name,
    required List<GroupItemDraft> items,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.groups,
      data: _groupPayload(name: name, items: items),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return GroupModel.fromJson(payload);
  }

  /// Partial update via `PATCH /group/{id}/`. Mirrors [createGroup] fields.
  Future<GroupModel> updateGroup({
    required String id,
    required String name,
    required List<GroupItemDraft> items,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.groupById(id),
      data: _groupPayload(name: name, items: items),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return GroupModel.fromJson(payload);
  }

  /// Fetches the list of available composite items used to populate
  /// the [AddGroupPage] dropdown. Walks all pages so the picker shows everything.
  Future<List<CompositeItemRef>> fetchCompositeItemOptions() async {
    final results = <String, CompositeItemRef>{};
    int page = 1;
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        AppApiUrls.compositeItems,
        queryParameters: <String, dynamic>{'page': page},
      );
      final root = response.data ?? const <String, dynamic>{};
      final rows = _readRows(root);
      if (rows.isEmpty) break;
      for (final row in rows) {
        final ref = CompositeItemRef.fromJson(row);
        if (ref != null) {
          results.putIfAbsent(ref.id, () => ref);
        }
      }
      final pagination = _readMap(root['pagination']);
      final currentPage = _readInt(pagination, const ['current_page']) ?? page;
      final totalPages = _readInt(pagination, const ['total_pages']) ?? 1;
      if (currentPage >= totalPages) break;
      page = currentPage + 1;
      // Safety bound against runaway pagination.
      if (page > 50) break;
    }
    return results.values.toList();
  }

  static Map<String, dynamic> _groupPayload({
    required String name,
    required List<GroupItemDraft> items,
  }) {
    return <String, dynamic>{
      'name': name,
      'group_name': name,
      'composite_items': items.map((e) => e.toJson()).toList(),
    };
  }

  static List<Map<String, dynamic>> _readRows(Map<String, dynamic> root) {
    final raw = root['data'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _readMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

final groupsApiClientProvider = Provider<GroupsApiClient>(
  (ref) => sl<GroupsApiClient>(),
);
