import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
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

  Future<ClientsPageResult> fetchClientsPage({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.clients,
      queryParameters: <String, dynamic>{'page': page},
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = _readRows(root);
    final clients = rows.map(ClientModel.fromJson).toList();
    final pagination = _readMap(root['pagination']);
    final currentPage = _readInt(pagination, const ['current_page']) ?? page;
    final totalPages = _readInt(pagination, const ['total_pages']) ?? 1;
    final totalRecords = _readInt(pagination, const ['total_records']) ?? clients.length;
    return ClientsPageResult(
      items: clients,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalRecords: totalRecords < 0 ? 0 : totalRecords,
    );
  }

  Future<ClientModel> fetchClientDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(AppApiUrls.clientsById(id));
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ClientModel.fromJson(payload);
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
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ClientModel.fromJson(payload);
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
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ClientModel.fromJson(payload);
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

final clientsApiClientProvider = Provider<ClientsApiClient>(
  (ref) => sl<ClientsApiClient>(),
);

