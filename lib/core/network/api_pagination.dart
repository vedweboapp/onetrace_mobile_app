import 'dart:convert';

import 'package:red5/core/network/api_int_parsing.dart';

/// Default list page size for paginated REST endpoints.
const int kDefaultApiPageSize = 20;

/// Parsed pagination metadata from a list API response.
class ApiPageMeta {
  const ApiPageMeta({
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.hasNextPage,
  });

  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final bool hasNextPage;
}

Map<String, dynamic> readApiMap(dynamic raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (_) {}
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>>? _readApiRowsFromListKeys(Map<String, dynamic> root) {
  for (final key in const ['data', 'results', 'items']) {
    final raw = root[key];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return null;
}

/// Pagination block from root or nested under `data.pagination`.
Map<String, dynamic> readApiPaginationBlock(Map<String, dynamic> root) {
  final nested = readApiMap(readApiMap(root['data'])['pagination']);
  if (nested.isNotEmpty) return nested;
  return readApiMap(root['pagination']);
}

/// Reads list rows from common API envelope shapes (`data`, `results`, nested pagination).
List<Map<String, dynamic>> readApiRows(Map<String, dynamic> root) {
  final direct = _readApiRowsFromListKeys(root);
  if (direct != null) return direct;

  final data = root['data'];
  if (data is Map) {
    final dataMap = Map<String, dynamic>.from(
      data.map((k, v) => MapEntry(k.toString(), v)),
    );
    final nested = _readApiRowsFromListKeys(dataMap);
    if (nested != null) return nested;

    final fromDataPagination = _readApiRowsFromListKeys(
      readApiMap(dataMap['pagination']),
    );
    if (fromDataPagination != null) return fromDataPagination;
  }

  final fromPagination = _readApiRowsFromListKeys(readApiPaginationBlock(root));
  if (fromPagination != null) return fromPagination;

  return const <Map<String, dynamic>>[];
}

/// Single-entity body from detail/create responses (`data` wrapper or root).
Map<String, dynamic> readApiEntityBody(Map<String, dynamic> root) {
  final data = readApiMap(root['data']);
  return data.isNotEmpty ? data : root;
}

/// Entity from create/update responses when `data` is an object or a list.
Map<String, dynamic> readApiMutationEntityBody(
  Map<String, dynamic> root, {
  Map<String, dynamic>? matchPayload,
}) {
  final data = root['data'];
  if (data is Map) return readApiMap(data);

  if (data is List && data.isNotEmpty) {
    final rows = data
        .whereType<Map>()
        .map(
          (row) => Map<String, dynamic>.from(
            row.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .toList();
    if (rows.isEmpty) return readApiEntityBody(root);

    if (matchPayload != null) {
      final email = matchPayload['email']?.toString().trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        for (final row in rows) {
          final rowEmail = row['email']?.toString().trim().toLowerCase();
          if (rowEmail == email) return row;
        }
      }

      final name = matchPayload['name']?.toString().trim().toLowerCase();
      if (name != null && name.isNotEmpty) {
        for (final row in rows) {
          final rowName = row['name']?.toString().trim().toLowerCase();
          if (rowName == name) return row;
        }
      }
    }

    rows.sort((a, b) {
      final idA = readApiIntFromMap(a, const ['id']) ?? 0;
      final idB = readApiIntFromMap(b, const ['id']) ?? 0;
      return idB.compareTo(idA);
    });
    return rows.first;
  }

  return readApiEntityBody(root);
}

bool readApiHasNextPage(Map<String, dynamic> root) {
  final next = root['next'];
  if (next != null && next.toString().trim().isNotEmpty) return true;
  final pagination = readApiPaginationBlock(root);
  final pagNext = pagination['next'];
  return pagNext != null && pagNext.toString().trim().isNotEmpty;
}

ApiPageMeta readApiPageMeta(Map<String, dynamic> root, {required int page}) {
  final pagination = readApiPaginationBlock(root);
  final currentPage =
      readApiIntFromMap(pagination, const ['current_page']) ??
      readApiIntFromMap(root, const ['current_page', 'page']) ??
      (page < 1 ? 1 : page);
  final totalPages =
      readApiIntFromMap(pagination, const ['total_pages']) ??
      readApiIntFromMap(root, const ['total_pages', 'pages']) ??
      1;
  final totalRecords =
      readApiIntFromMap(pagination, const ['total_records']) ??
      readApiIntFromMap(root, const [
        'total_records',
        'count',
        'total',
        'total_count',
      ]) ??
      readApiRows(root).length;

  return ApiPageMeta(
    currentPage: currentPage < 1 ? 1 : currentPage,
    totalPages: totalPages < 1 ? 1 : totalPages,
    totalRecords: totalRecords < 0 ? 0 : totalRecords,
    hasNextPage: readApiHasNextPage(root),
  );
}

/// Standard list query params: `page`, `page_size`, optional `search`, plus [extra].
Map<String, dynamic> buildListQuery({
  required int page,
  int pageSize = kDefaultApiPageSize,
  String? search,
  Map<String, dynamic>? extra,
}) {
  final query = <String, dynamic>{
    'page': page < 1 ? 1 : page,
    'page_size': pageSize,
    ...?extra,
  };
  final term = search?.trim();
  if (term != null && term.isNotEmpty) {
    query['search'] = term;
  }
  return query;
}
