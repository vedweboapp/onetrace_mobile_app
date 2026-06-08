import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/clients/data/client_models.dart';

class ClientsPageResult {
  const ClientsPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<ClientModel> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

final class ClientsApiClient {
  ClientsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const int defaultPageSize = kDefaultApiPageSize;

  Future<ClientsPageResult> fetchClientsPage({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.clients,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final clients = rows.map(ClientModel.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return ClientsPageResult(
      items: clients,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  Future<ClientModel> fetchClientDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(AppApiUrls.clientsById(id));
    final root = response.data ?? const <String, dynamic>{};
    return ClientModel.fromJson(readApiEntityBody(root));
  }

  Future<ClientModel> createClient({
    required String name,
    required String contactPerson,
    required String email,
    required String phone,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String state,
    required String country,
    required String pincode,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.clients,
      data: <String, dynamic>{
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city': city,
        'state': state,
        'country': country,
        'pincode': pincode,
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    return ClientModel.fromJson(readApiEntityBody(root));
  }

  /// `PUT /api/v1/clients/{id}/` — same field set as [createClient].
  Future<ClientModel> updateClient({
    required String id,
    required String name,
    required String contactPerson,
    required String email,
    required String phone,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String state,
    required String country,
    required String pincode,
    required bool isActive,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      AppApiUrls.clientsById(id.trim()),
      data: <String, dynamic>{
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city': city,
        'state': state,
        'country': country,
        'pincode': pincode,
        'is_active': isActive,
      },
    );
    final root = response.data ?? const <String, dynamic>{};
    return ClientModel.fromJson(readApiEntityBody(root));
  }
}

final clientsApiClientProvider = Provider<ClientsApiClient>(
  (ref) => sl<ClientsApiClient>(),
);

