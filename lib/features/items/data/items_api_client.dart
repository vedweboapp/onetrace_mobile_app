import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/items/data/item_models.dart';

class ItemsPageResult {
  const ItemsPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<ItemModel> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

/// `GET /api/v1/item/?page=&page_size=&is_composite=` (non-composite catalog rows).
final class ItemsApiClient {
  ItemsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;
  static const int defaultPageSize = kDefaultApiPageSize;

  Future<ItemsPageResult> fetchItemsPage({
    int page = 1,
    int pageSize = defaultPageSize,
    bool isComposite = false,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.items,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
        extra: <String, dynamic>{'is_composite': isComposite},
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final items = rows.map(ItemModel.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return ItemsPageResult(
      items: items,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  /// `GET /api/v1/item/{id}/` — full detail for one catalog row.
  Future<ItemDetailModel> fetchItemDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.itemById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    return ItemDetailModel.fromJson(readApiEntityBody(root));
  }

  /// `POST /api/v1/item/` — create a non-composite catalog row.
  Future<ItemModel> createItem({
    required String name,
    required String sku,
    double quantity = 0,
    double costPrice = 0,
    double sellingPrice = 0,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.items,
      data: <String, dynamic>{
        'name': name,
        'sku': sku,
        'quantity': quantity,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'is_composite': false,
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    return ItemModel.fromJson(readApiEntityBody(root));
  }

  /// `POST /api/v1/item/` — composite row
  Future<ItemModel> createCompositeItem({
    required String name,
    required String sku,
    double quantity = 0,
    double costPrice = 0,
    double sellingPrice = 0,
    required List<({String itemId, double quantity})> componentLines,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.items,
      data: <String, dynamic>{
        'name': name,
        'sku': sku,
        'quantity': quantity,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'is_composite': true,
        'items': componentLines
            .map(
              (e) => <String, dynamic>{
                'item': e.itemId,
                'quantity': e.quantity,
              },
            )
            .toList(),
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    return ItemModel.fromJson(readApiEntityBody(root));
  }

  /// `PUT /api/v1/item/{id}/` — update a catalog row
  Future<ItemModel> updateItem({
    required String id,
    required String name,
    required String sku,
    double quantity = 0,
    double costPrice = 0,
    double sellingPrice = 0,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      AppApiUrls.itemById(id),
      data: <String, dynamic>{
        'name': name,
        'sku': sku,
        'quantity': quantity,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'is_composite': false,
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    return ItemModel.fromJson(readApiEntityBody(root));
  }

  /// `PUT /api/v1/item/{id}/` — update composite item
  Future<ItemModel> updateCompositeItem({
    required String id,
    required String name,
    required String sku,
    double quantity = 0,
    double costPrice = 0,
    double sellingPrice = 0,
    required List<({String itemId, double quantity})> componentLines,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      AppApiUrls.itemById(id),
      data: <String, dynamic>{
        'name': name,
        'sku': sku,
        'quantity': quantity,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'is_composite': true,
        'items': componentLines
            .map(
              (e) => <String, dynamic>{
                'item': e.itemId,
                'quantity': e.quantity,
              },
            )
            .toList(),
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    return ItemModel.fromJson(readApiEntityBody(root));
  }
}

final itemsApiClientProvider = Provider<ItemsApiClient>(
  (ref) => sl<ItemsApiClient>(),
);