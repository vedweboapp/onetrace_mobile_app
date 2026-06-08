import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/dashboard/data/invoice_models.dart';

class InvoicesPageResult {
  const InvoicesPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<InvoiceListItem> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

/// `GET/POST /api/v1/invoice/` and `GET /api/v1/invoice/{id}/`.
final class InvoicesApiClient {
  InvoicesApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const int defaultPageSize = kDefaultApiPageSize;

  Future<InvoicesPageResult> fetchInvoicesPage({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
    int? clientId,
    String? status,
    String? issueDate,
    String? dueDate,
  }) async {
    final extra = <String, dynamic>{};
    if (clientId != null) extra['client'] = clientId;
    if (status != null && status.trim().isNotEmpty) {
      extra['status'] = status.trim();
    }
    if (issueDate != null && issueDate.trim().isNotEmpty) {
      extra['issue_date'] = issueDate.trim();
    }
    if (dueDate != null && dueDate.trim().isNotEmpty) {
      extra['due_date'] = dueDate.trim();
    }

    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.invoices,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
        extra: extra.isEmpty ? null : extra,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final items = rows.map(InvoiceListItem.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return InvoicesPageResult(
      items: items,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  Future<InvoiceDetail> fetchInvoiceDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.invoiceById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    return InvoiceDetail.fromJson(readApiEntityBody(root));
  }

  Future<InvoiceDetail> createInvoice(InvoiceCreatePayload payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.invoices,
      data: payload.toJson(),
    );
    final root = response.data ?? const <String, dynamic>{};
    return InvoiceDetail.fromJson(readApiEntityBody(root));
  }

  /// Placeholder until backend exposes invoice PDF generation.
  Future<List<int>> downloadInvoicePdf(String id) async {
    throw const InvoicePdfNotAvailableException();
  }

  /// Placeholder until backend exposes invoice PDF generation.
  Future<void> printInvoice(String id) async {
    throw const InvoicePdfNotAvailableException();
  }
}

/// Raised when the invoice PDF endpoint is not yet available on the server.
final class InvoicePdfNotAvailableException implements Exception {
  const InvoicePdfNotAvailableException();

  @override
  String toString() => 'Invoice PDF API is not available yet';
}

final invoicesApiClientProvider = Provider<InvoicesApiClient>(
  (ref) => sl<InvoicesApiClient>(),
);
