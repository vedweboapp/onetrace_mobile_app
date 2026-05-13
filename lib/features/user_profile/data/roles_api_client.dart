import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/user_profile/data/role_models.dart';

class RolesPageResult {
  const RolesPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<RoleModel> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

/// HTTP client for `GET /api/v1/role/`.
final class RolesApiClient {
  RolesApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<RolesPageResult> fetchRolesPage({
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.roles,
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = _readRows(root);
    final items = rows.map(RoleModel.fromJson).toList();
    final pagination = _readMap(root['pagination']);
    final currentPage = _readInt(pagination, const ['current_page']) ?? page;
    final totalPages = _readInt(pagination, const ['total_pages']) ?? 1;
    final totalRecords =
        _readInt(pagination, const ['total_records']) ?? items.length;
    return RolesPageResult(
      items: items,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalRecords: totalRecords < 0 ? 0 : totalRecords,
    );
  }

  /// Loads every page until all roles are collected.
  Future<List<RoleModel>> fetchAllRoles({int pageSize = 50}) async {
    final out = <RoleModel>[];
    var page = 1;
    while (true) {
      final r = await fetchRolesPage(page: page, pageSize: pageSize);
      out.addAll(r.items);
      if (page >= r.totalPages || r.items.isEmpty) break;
      page++;
    }
    return out;
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

final rolesApiClientProvider = Provider<RolesApiClient>(
  (ref) => sl<RolesApiClient>(),
);
