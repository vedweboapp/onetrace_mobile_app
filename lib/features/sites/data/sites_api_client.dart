import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
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

  /// `GET /site/` — [site_list] with pagination.
  Future<SitesPageResult> fetchSitesPage({
    int page = 1,
    int pageSize = kDefaultApiPageSize,
    int? clientId,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.sites,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
        extra: clientId != null ? <String, dynamic>{'client': clientId} : null,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final sites = rows.map(SiteModel.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return SitesPageResult(
      items: sites,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  /// Loads every page from `GET /site/` (optionally filtered by [clientId]).
  Future<List<SiteModel>> fetchAllSites({
    int? clientId,
    int pageSize = 50,
  }) async {
    final out = <SiteModel>[];
    final seen = <String>{};
    var page = 1;

    while (true) {
      final result = await fetchSitesPage(
        page: page,
        pageSize: pageSize,
        clientId: clientId,
      );
      for (final site in result.items) {
        if (site.id.isEmpty || !seen.add(site.id)) continue;
        if (!site.isActive) continue;
        out.add(site);
      }
      if (page >= result.totalPages || result.items.isEmpty) break;
      page += 1;
    }

    return out;
  }

  /// `GET /site/{id}/` — [site_read]
  Future<SiteModel> fetchSiteDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.siteById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    return SiteModel.fromJson(readApiEntityBody(root));
  }

  Future<SiteModel> createSite({
    required String siteName,
    required String clientId,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
    String what3Words = '',
    List<SiteContactPerson> contactPersons = const [],
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.sites,
      data: _sitePayload(
        siteName: siteName,
        clientId: clientId,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        country: country,
        city: city,
        state: state,
        postalCode: postalCode,
        what3Words: what3Words,
        contactPersons: contactPersons,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    return SiteModel.fromJson(readApiEntityBody(root));
  }

  /// Partial update via `PATCH /site/{id}/`.
  Future<SiteModel> updateSite({
    required String id,
    required String siteName,
    required String clientId,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
    String what3Words = '',
    List<SiteContactPerson> contactPersons = const [],
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.siteById(id),
      data: _sitePayload(
        siteName: siteName,
        clientId: clientId,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        country: country,
        city: city,
        state: state,
        postalCode: postalCode,
        what3Words: what3Words,
        contactPersons: contactPersons,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    return SiteModel.fromJson(readApiEntityBody(root));
  }

  static Map<String, dynamic> _sitePayload({
    required String siteName,
    required String clientId,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
    String what3Words = '',
    List<SiteContactPerson> contactPersons = const [],
  }) {
    return <String, dynamic>{
      'site_name': siteName,
      'name': siteName,
      'client': _clientJsonValue(clientId),
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'country': country,
      'city': city,
      'state': state,
      'pincode': postalCode,
      'postal_code': postalCode,
      'what3words': what3Words.trim(),
      'contact_persons': contactPersons
          .where((c) => c.contactId.trim().isNotEmpty)
          .map((c) => c.toJson())
          .toList(growable: false),
    };
  }

  /// Backend expects a `client` FK; send int when the id is numeric, else raw string.
  static Object _clientJsonValue(String clientId) {
    final t = clientId.trim();
    final asInt = int.tryParse(t);
    return asInt ?? t;
  }
}

final sitesApiClientProvider = Provider<SitesApiClient>(
  (ref) => sl<SitesApiClient>(),
);
