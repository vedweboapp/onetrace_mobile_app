import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/contacts/data/contact_models.dart';

class ContactsPageResult {
  const ContactsPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<ContactModel> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}

final class ContactsApiClient {
  ContactsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<ContactsPageResult> fetchContactsPage({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.contacts,
      queryParameters: <String, dynamic>{'page': page},
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = _readRows(root);
    final contacts = rows.map(ContactModel.fromJson).toList();
    final pagination = _readMap(root['pagination']);
    final currentPage = _readInt(pagination, const ['current_page']) ?? page;
    final totalPages = _readInt(pagination, const ['total_pages']) ?? 1;
    final totalRecords =
        _readInt(pagination, const ['total_records']) ?? contacts.length;
    return ContactsPageResult(
      items: contacts,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalRecords: totalRecords < 0 ? 0 : totalRecords,
    );
  }

  Future<ContactModel> fetchContactDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.contactById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return ContactModel.fromJson(payload);
  }

  Future<ContactModel> createContact({
    required String contactName,
    required String clientName,
    required String email,
    required String phone,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppApiUrls.contacts,
      data: _contactPayload(
        contactName: contactName,
        clientName: clientName,
        email: email,
        phone: phone,
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
    return ContactModel.fromJson(payload);
  }

  /// Partial update via `PATCH /contact/{id}/`. Mirrors [createContact] fields.
  Future<ContactModel> updateContact({
    required String id,
    required String contactName,
    required String clientName,
    required String email,
    required String phone,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.contactById(id),
      data: _contactPayload(
        contactName: contactName,
        clientName: clientName,
        email: email,
        phone: phone,
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
    return ContactModel.fromJson(payload);
  }

  static Map<String, dynamic> _contactPayload({
    required String contactName,
    required String clientName,
    required String email,
    required String phone,
    required String addressLine1,
    required String addressLine2,
    required String country,
    required String city,
    required String state,
    required String postalCode,
  }) {
    return <String, dynamic>{
      'contact_name': contactName,
      'name': contactName,
      'client_name': clientName,
      'email': email,
      'phone': phone,
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

final contactsApiClientProvider = Provider<ContactsApiClient>(
  (ref) => sl<ContactsApiClient>(),
);
