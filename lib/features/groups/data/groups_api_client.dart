import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
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

  Future<GroupsPageResult> fetchGroupsPage({
    int page = 1,
    int pageSize = kDefaultApiPageSize,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.groups,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final groups = rows.map(GroupModel.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return GroupsPageResult(
      items: groups,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  Future<GroupModel> fetchGroupDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.groupById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    return GroupModel.fromJson(readApiEntityBody(root));
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
    return GroupModel.fromJson(readApiEntityBody(root));
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
    return GroupModel.fromJson(readApiEntityBody(root));
  }

  /// Fetches the list of available composite items used to populate
  /// the [AddGroupPage] dropdown. Walks all pages so the picker shows everything.
  ///
  /// Uses `GET /api/v1/item/?is_composite=true` (same catalog as items list).
  Future<List<CompositeItemRef>> fetchCompositeItemOptions() async {
    final results = <String, CompositeItemRef>{};
    int page = 1;
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        AppApiUrls.items,
        queryParameters: buildListQuery(
          page: page,
          pageSize: kDefaultApiPageSize,
          extra: const <String, dynamic>{'is_composite': true},
        ),
      );
      final root = response.data ?? const <String, dynamic>{};
      final rows = readApiRows(root);
      if (rows.isEmpty) break;
      for (final row in rows) {
        final ref = CompositeItemRef.fromJson(row);
        if (ref != null) {
          results.putIfAbsent(ref.id, () => ref);
        }
      }
      final meta = readApiPageMeta(root, page: page);
      if (meta.currentPage >= meta.totalPages) break;
      page = meta.currentPage + 1;
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
}

final groupsApiClientProvider = Provider<GroupsApiClient>(
  (ref) => sl<GroupsApiClient>(),
);
