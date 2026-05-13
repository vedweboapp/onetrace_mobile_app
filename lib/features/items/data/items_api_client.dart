import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
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

  static const int defaultPageSize = 20;

  Future<ItemsPageResult> fetchItemsPage({
    int page = 1,
    int pageSize = defaultPageSize,
    bool isComposite = false,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.items,
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'is_composite': isComposite,
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = _readRows(root);
    final items = rows.map(ItemModel.fromJson).toList();
    final pagination = _readMap(root['pagination']);
    final currentPage = _readInt(pagination, const ['current_page']) ?? page;
    final totalPages = _readInt(pagination, const ['total_pages']) ?? 1;
    final totalRecords =
        _readInt(pagination, const ['total_records']) ?? items.length;
    return ItemsPageResult(
      items: items,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalRecords: totalRecords < 0 ? 0 : totalRecords,
    );
  }

  /// `GET /api/v1/item/{id}/` — full detail for one catalog row.
  Future<ItemDetailModel> fetchItemDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.itemById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ItemDetailModel.fromJson(payload);
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
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ItemModel.fromJson(payload);
  }

  /// `POST /api/v1/item/` — composite row with child lines (`items`: `[{ item, quantity }]`).
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
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ItemModel.fromJson(payload);
  }

  /// `PUT /api/v1/item/{id}/` — update a catalog row (same body shape as create).
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
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ItemModel.fromJson(payload);
  }

  /// `PUT /api/v1/item/{id}/` — update composite item + component lines.
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
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ItemModel.fromJson(payload);
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

final itemsApiClientProvider = Provider<ItemsApiClient>(
  (ref) => sl<ItemsApiClient>(),
);
