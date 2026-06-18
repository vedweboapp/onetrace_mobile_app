import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';

class VendorsPageResult {
  const VendorsPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<VendorModel> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

final class VendorsApiClient {
  VendorsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const int defaultPageSize = kDefaultApiPageSize;

  Future<VendorsPageResult> fetchVendorsPage({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
    String? type,
    bool? isActive,
  }) async {
    final extra = <String, dynamic>{};
    final typeFilter = type?.trim();
    if (typeFilter != null && typeFilter.isNotEmpty) {
      extra['type'] = typeFilter;
    }
    if (isActive != null) {
      extra['is_active'] = isActive;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.vendors,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
        extra: extra.isEmpty ? null : extra,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final vendors = rows.map(VendorModel.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return VendorsPageResult(
      items: vendors,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  Future<VendorModel> fetchVendorDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.vendorsById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    return VendorModel.fromJson(readApiEntityBody(root));
  }

  Future<VendorModel> createVendor(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.vendors,
      data: payload,
    );
    final root = response.data ?? const <String, dynamic>{};
    return VendorModel.fromJson(readApiEntityBody(root));
  }

  Future<void> deleteVendor(String id) async {
    await _dio.delete<void>(AppApiUrls.vendorsById(id));
  }

  /// `GET /api/v1/vendor-type/` — options for the create-vendor type dropdown.
  Future<List<VendorTypeOption>> fetchVendorTypes() async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.vendorTypes,
      queryParameters: const <String, dynamic>{
        'page': 1,
        'page_size': 500,
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final seen = <int>{};
    final options = <VendorTypeOption>[];
    for (final row in rows) {
      final option = VendorTypeOption.fromJson(row);
      if (option.id <= 0 || !seen.add(option.id)) continue;
      options.add(option);
    }
    return options;
  }
}

final vendorsApiClientProvider = Provider<VendorsApiClient>(
  (ref) => sl<VendorsApiClient>(),
);
