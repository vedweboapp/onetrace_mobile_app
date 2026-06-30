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
    String? contactType,
    String? vendorId,
    String? clientId,
  }) async {
    final extra = <String, dynamic>{};
    final type = contactType?.trim();
    if (type != null && type.isNotEmpty) {
      extra['contact_type'] = type;
    }
    final vendor = vendorId?.trim();
    if (vendor != null && vendor.isNotEmpty) {
      extra['vendor'] = int.tryParse(vendor) ?? vendor;
    }
    final client = clientId?.trim();
    if (client != null && client.isNotEmpty) {
      extra['client'] = int.tryParse(client) ?? client;
    }

    final response = await _dio.get<dynamic>(
      AppApiUrls.contacts,
      queryParameters: buildListQuery(
        page: page,
        pageSize: pageSize,
        search: search,
        extra: extra.isEmpty ? null : extra,
      ),
    );
    final root = readApiMap(response.data);
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

  /// `GET /contact/?contact_type=vendor&vendor={id}` — contacts for a vendor.
  Future<List<ContactModel>> fetchVendorContacts({
    required String vendorId,
    String? search,
    int pageSize = defaultPageSize,
  }) async {
    final id = vendorId.trim();
    if (id.isEmpty) return const [];

    final merged = <String, ContactModel>{};
    var page = 1;
    var totalPages = 1;
    const maxPages = 40;

    do {
      final result = await fetchContactsPage(
        page: page,
        pageSize: pageSize,
        search: search,
        contactType: ContactTypeValues.vendor,
        vendorId: id,
      );
      for (final contact in result.items) {
        final key = contact.id.trim();
        if (key.isNotEmpty) merged[key] = contact;
      }
      totalPages = result.totalPages;
      page++;
    } while (page <= totalPages && page <= maxPages);

    final list = merged.values.toList()
      ..sort(
        (a, b) =>
            a.contactName.toLowerCase().compareTo(b.contactName.toLowerCase()),
      );
    return list;
  }

  Future<ContactModel> fetchContactDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.contactById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    return ContactModel.fromJson(_readContactEntityBody(root));
  }

  static Map<String, dynamic> _readContactEntityBody(
    Map<String, dynamic> root,
  ) {
    final data = root['data'];
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map) {
        return Map<String, dynamic>.from(
          first.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return readApiEntityBody(root);
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
      'pincode': postalCode,
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
