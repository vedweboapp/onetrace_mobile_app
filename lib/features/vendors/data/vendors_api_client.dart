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
      extra['is_active'] = isActive.toString();
    }

    final response = await _dio.get<dynamic>(
      AppApiUrls.vendors,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
        extra: extra.isEmpty ? null : extra,
      ),
    );
    final root = readApiMap(response.data);
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
    final response = await _dio.get<dynamic>(AppApiUrls.vendorsById(id));
    final root = readApiMap(response.data);
    return VendorModel.fromJson(readApiMutationEntityBody(root));
  }

  Future<VendorModel> createVendor(Map<String, dynamic> payload) async {
    final response = await _dio.post<dynamic>(
      AppApiUrls.vendors,
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
    return VendorModel.fromJson(body);
  }

  Future<VendorModel> updateVendor(
    String id,
    Map<String, dynamic> payload, {
    bool partial = false,
  }) async {
    final response = partial
        ? await _dio.patch<dynamic>(
            AppApiUrls.vendorsById(id),
            data: payload,
            options: Options(
              headers: const <String, dynamic>{
                Headers.acceptHeader: Headers.jsonContentType,
                Headers.contentTypeHeader: Headers.jsonContentType,
              },
            ),
          )
        : await _dio.put<dynamic>(
            AppApiUrls.vendorsById(id),
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
    return VendorModel.fromJson(body);
  }

  Future<void> deleteVendor(String id) async {
    await _dio.delete<void>(AppApiUrls.vendorsById(id));
  }

  Future<VendorTypeOption> fetchVendorTypeDetail(int id) async {
    final response = await _dio.get<dynamic>(AppApiUrls.vendorTypeById('$id'));
    final root = readApiMap(response.data);
    return VendorTypeOption.fromJson(readApiMutationEntityBody(root));
  }

  Future<VendorTypeOption> createVendorType(Map<String, dynamic> payload) async {
    final response = await _dio.post<dynamic>(
      AppApiUrls.vendorTypes,
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
    return VendorTypeOption.fromJson(body);
  }

  Future<VendorTypeOption> updateVendorType(
    int id,
    Map<String, dynamic> payload, {
    bool partial = false,
  }) async {
    final response = partial
        ? await _dio.patch<dynamic>(
            AppApiUrls.vendorTypeById('$id'),
            data: payload,
            options: Options(
              headers: const <String, dynamic>{
                Headers.acceptHeader: Headers.jsonContentType,
                Headers.contentTypeHeader: Headers.jsonContentType,
              },
            ),
          )
        : await _dio.put<dynamic>(
            AppApiUrls.vendorTypeById('$id'),
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
    return VendorTypeOption.fromJson(body);
  }

  Future<void> deleteVendorType(int id) async {
    await _dio.delete<void>(AppApiUrls.vendorTypeById('$id'));
  }

  /// `GET /api/v1/vendor-type/` — searchable options for create-vendor type picker.
  Future<List<VendorTypeOption>> fetchVendorTypes({
    int page = 1,
    int pageSize = 100,
    String? search,
    bool isActive = true,
  }) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.vendorTypes,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
        extra: <String, dynamic>{'is_active': isActive.toString()},
      ),
    );
    final root = readApiMap(response.data);
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
