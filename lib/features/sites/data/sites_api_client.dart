import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/sites/data/site_models.dart';

class SitesPageResult {
  const SitesPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<SiteModel> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

final class SitesApiClient {
  SitesApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<SitesPageResult> fetchSitesPage({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.items,
      queryParameters: <String, dynamic>{'page': page},
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = _readRows(root);
    final sites = rows.map(SiteModel.fromJson).toList();
    final pagination = _readMap(root['pagination']);
    final currentPage = _readInt(pagination, const ['current_page']) ?? page;
    final totalPages = _readInt(pagination, const ['total_pages']) ?? 1;
    final totalRecords =
        _readInt(pagination, const ['total_records']) ?? sites.length;
    return SitesPageResult(
      items: sites,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalRecords: totalRecords < 0 ? 0 : totalRecords,
    );
  }

  Future<SiteModel> fetchSiteDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.itemById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return SiteModel.fromJson(payload);
  }

  Future<SiteModel> createSite({
    required String siteName,
    required String clientName,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.items,
      data: _sitePayload(
        siteName: siteName,
        clientName: clientName,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        country: country,
        city: city,
        state: state,
        postalCode: postalCode,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return SiteModel.fromJson(payload);
  }

  /// Partial update via `PATCH /item/{id}/`. Mirrors [createSite] fields.
  Future<SiteModel> updateSite({
    required String id,
    required String siteName,
    required String clientName,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.itemById(id),
      data: _sitePayload(
        siteName: siteName,
        clientName: clientName,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        country: country,
        city: city,
        state: state,
        postalCode: postalCode,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return SiteModel.fromJson(payload);
  }

  static Map<String, dynamic> _sitePayload({
    required String siteName,
    required String clientName,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
  }) {
    return <String, dynamic>{
      'site_name': siteName,
      'name': siteName,
      'client_name': clientName,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'country': country,
      'city': city,
      'state': state,
      'postal_code': postalCode,
    };
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

final sitesApiClientProvider = Provider<SitesApiClient>(
  (ref) => sl<SitesApiClient>(),
);
