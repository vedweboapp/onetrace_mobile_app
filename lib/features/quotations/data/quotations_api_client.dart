import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
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

  static const int defaultPageSize = kDefaultApiPageSize;

  Future<QuotationsPageResult> fetchQuotationsPage({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.quotations,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final items = rows.map(QuotationListItem.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return QuotationsPageResult(
      items: items,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  Future<QuotationDetailModel> fetchQuotationDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.quotationById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    return QuotationDetailModel.fromJson(readApiEntityBody(root));
  }

  /// `POST /api/v1/quotations/` — server may accept a subset of fields.
  Future<QuotationListItem> createQuotation(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.quotations,
      data: body,
    );
    final root = response.data ?? const <String, dynamic>{};
    return QuotationListItem.fromJson(readApiEntityBody(root));
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
    return QuotationListItem.fromJson(readApiEntityBody(root));
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
}

final quotationsApiClientProvider = Provider<QuotationsApiClient>(
  (ref) => sl<QuotationsApiClient>(),
);
