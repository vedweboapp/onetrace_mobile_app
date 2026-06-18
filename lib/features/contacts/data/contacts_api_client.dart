import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
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

  static const int defaultPageSize = kDefaultApiPageSize;

  Future<ContactsPageResult> fetchContactsPage({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.contacts,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = readApiRows(root);
    final contacts = rows.map(ContactModel.fromJson).toList();
    final meta = readApiPageMeta(root, page: page);
    return ContactsPageResult(
      items: contacts,
      currentPage: meta.currentPage,
      totalPages: meta.totalPages,
      totalRecords: meta.totalRecords,
    );
  }

  Future<ContactModel> fetchContactDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.contactById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    return ContactModel.fromJson(readApiEntityBody(root));
  }

  Future<ContactModel> createContact({
    required String contactName,
    required String contactType,
    required String clientId,
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
        contactType: contactType,
        clientId: clientId,
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
    return ContactModel.fromJson(readApiEntityBody(root));
  }

  /// Partial update via `PATCH /contact/{id}/`. Mirrors [createContact] fields.
  Future<ContactModel> updateContact({
    required String id,
    required String contactName,
    required String contactType,
    required String clientId,
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
        contactType: contactType,
        clientId: clientId,
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
    return ContactModel.fromJson(readApiEntityBody(root));
  }

  static Map<String, dynamic> _contactPayload({
    required String contactName,
    required String contactType,
    required String clientId,
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
      'contact_type': ContactTypeValues.normalize(contactType) ??
          contactType.trim().toLowerCase(),
      'client': _clientJsonValue(clientId),
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

  /// Backend expects a `client` FK; send int when the id is numeric, else raw string.
  static Object _clientJsonValue(String clientId) {
    final t = clientId.trim();
    final asInt = int.tryParse(t);
    return asInt ?? t;
  }
}

final contactsApiClientProvider = Provider<ContactsApiClient>(
  (ref) => sl<ContactsApiClient>(),
);
