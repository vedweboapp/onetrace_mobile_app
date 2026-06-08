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
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

/// Reads list rows from common API envelope shapes (`data`, `results`, nested pagination).
List<Map<String, dynamic>> readApiRows(Map<String, dynamic> root) {
  for (final key in const ['data', 'results', 'items']) {
    final raw = root[key];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  final pagination = readApiMap(root['pagination']);
  for (final key in const ['data', 'results']) {
    final nested = pagination[key];
    if (nested is List) {
      return nested
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  return const <Map<String, dynamic>>[];
}

/// Single-entity body from detail/create responses (`data` wrapper or root).
Map<String, dynamic> readApiEntityBody(Map<String, dynamic> root) {
  final data = readApiMap(root['data']);
  return data.isNotEmpty ? data : root;
}

bool readApiHasNextPage(Map<String, dynamic> root) {
  final next = root['next'];
  if (next != null && next.toString().trim().isNotEmpty) return true;
  final pagination = readApiMap(root['pagination']);
  final pagNext = pagination['next'];
  return pagNext != null && pagNext.toString().trim().isNotEmpty;
}

ApiPageMeta readApiPageMeta(Map<String, dynamic> root, {required int page}) {
  final pagination = readApiMap(root['pagination']);
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
