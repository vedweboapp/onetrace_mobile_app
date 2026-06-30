import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/dashboard/data/purchase_order_models.dart';

class PurchaseOrdersPageResult {
  const PurchaseOrdersPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<PurchaseOrderListItem> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

final class PurchaseOrdersApiClient {
  PurchaseOrdersApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const int defaultPageSize = kDefaultApiPageSize;

  Future<PurchaseOrdersPageResult> fetchPurchaseOrdersPage({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
  }) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.purchaseOrders,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
      ),
    );
    final root = readApiMap(response.data);
    final rows = readApiRows(root);
    final items = rows.map(PurchaseOrderListItem.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return PurchaseOrdersPageResult(
      items: items,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  Future<PurchaseOrderDetail> fetchPurchaseOrderDetail(String id) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.purchaseOrderById(id),
    );
    final root = readApiMap(response.data);
    return PurchaseOrderDetail.fromJson(readApiMutationEntityBody(root));
  }

  Future<PurchaseOrderDetail> createPurchaseOrder(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<dynamic>(
      AppApiUrls.purchaseOrders,
      data: payload,
      options: Options(
        headers: const <String, dynamic>{
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    final root = readApiMap(response.data);
    final body = readApiMutationEntityBody(root, matchPayload: payload);
    return PurchaseOrderDetail.fromJson(body);
  }

  Future<PurchaseOrderDetail> updatePurchaseOrder(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch<dynamic>(
      AppApiUrls.purchaseOrderById(id),
      data: payload,
      options: Options(
        headers: const <String, dynamic>{
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    final root = readApiMap(response.data);
    final body = readApiMutationEntityBody(root, matchPayload: payload);
    return PurchaseOrderDetail.fromJson(body);
  }

  Future<void> deletePurchaseOrder(String id) async {
    await _dio.delete<void>(AppApiUrls.purchaseOrderById(id));
  }
}

final purchaseOrdersApiClientProvider = Provider<PurchaseOrdersApiClient>(
  (ref) => sl<PurchaseOrdersApiClient>(),
);
