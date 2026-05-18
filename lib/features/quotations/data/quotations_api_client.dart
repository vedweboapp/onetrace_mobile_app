import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/quotations/data/quotation_models.dart';

class QuotationsPageResult {
  const QuotationsPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<QuotationListItem> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

/// `GET/POST /api/v1/quotations/` and `GET/PUT/PATCH/DELETE /api/v1/quotations/{id}/`.
final class QuotationsApiClient {
  QuotationsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const int defaultPageSize = 20;

  Future<QuotationsPageResult> fetchQuotationsPage({
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.quotations,
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = _readRows(root);
    final items = rows.map(QuotationListItem.fromJson).toList();
    final pagination = _readMap(root['pagination']);
    final currentPage = _readInt(pagination, const ['current_page']) ?? page;
    final totalPages = _readInt(pagination, const ['total_pages']) ?? 1;
    final totalRecords =
        _readInt(pagination, const ['total_records']) ?? items.length;
    return QuotationsPageResult(
      items: items,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalRecords: totalRecords < 0 ? 0 : totalRecords,
    );
  }

  Future<QuotationDetailModel> fetchQuotationDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.quotationById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return QuotationDetailModel.fromJson(payload);
  }

  /// `POST /api/v1/quotations/` — server may accept a subset of fields.
  Future<QuotationListItem> createQuotation(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.quotations,
      data: body,
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return QuotationListItem.fromJson(payload);
  }

  Future<QuotationListItem> updateQuotation({
    required String id,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      AppApiUrls.quotationById(id),
      data: body,
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return QuotationListItem.fromJson(payload);
  }

  Future<void> patchQuotation({
    required String id,
    required Map<String, dynamic> body,
  }) async {
    await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.quotationById(id),
      data: body,
    );
  }

  Future<void> deleteQuotation(String id) async {
    await _dio.delete<void>(AppApiUrls.quotationById(id));
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

final quotationsApiClientProvider = Provider<QuotationsApiClient>(
  (ref) => sl<QuotationsApiClient>(),
);
