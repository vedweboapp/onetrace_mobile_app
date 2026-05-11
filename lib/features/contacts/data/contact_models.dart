import 'package:flutter/foundation.dart';

/// Lightweight reference to the parent `client` object embedded in
/// `/contact/` responses (e.g. `{"id": 3, "name": "Cu", "email": ...}`).
@immutable
class ContactClientRef {
  const ContactClientRef({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.email,
    required this.phone,
  });

  final String id;
  final String name;
  final String contactPerson;
  final String email;
  final String phone;

  bool get isEmpty =>
      id.isEmpty && name.isEmpty && email.isEmpty && phone.isEmpty;

  static const empty = ContactClientRef(
    id: '',
    name: '',
    contactPerson: '',
    email: '',
    phone: '',
  );

  factory ContactClientRef.fromJson(Map<String, dynamic> json) {
    return ContactClientRef(
      id: _readString(json, const ['id']),
      name: _readString(json, const ['name', 'client_name', 'title']),
      contactPerson: _readString(json, const ['contact_person', 'contact']),
      email: _readString(json, const ['email', 'email_address']),
      phone: _readString(json, const ['phone', 'phone_number', 'mobile']),
    );
  }
}

@immutable
class ContactModel {
  const ContactModel({
    required this.id,
    required this.contactName,
    required this.client,
    required this.email,
    required this.phone,
    required this.addressLine1,
    required this.addressLine2,
    required this.country,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.isActive,
  });

  final String id;
  final String contactName;
  final ContactClientRef client;
  final String email;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String country;
  final String city;
  final String state;
  final String postalCode;
  final bool isActive;

  /// Convenience accessor used widely by the UI. Falls back to the raw
  /// client id when the API returns only an integer reference without
  /// expanding the nested object.
  String get clientName {
    final n = client.name.trim();
    if (n.isNotEmpty) return n;
    return client.id.isEmpty ? '' : 'Client #${client.id}';
  }

  String get clientId => client.id;

  static ContactModel fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: _readString(json, const ['id']),
      contactName: _readString(
        json,
        const ['name', 'contact_name', 'full_name'],
        fallback: 'Contact Name',
      ),
      client: _readClient(json),
      email: _readString(json, const ['email', 'email_address']),
      phone: _readString(json, const ['phone', 'phone_number', 'mobile']),
      addressLine1: _readString(json, const [
        'address_line_1',
        'address_line1',
        'address',
      ]),
      addressLine2: _readString(json, const ['address_line_2', 'address_line2']),
      country: _readString(json, const ['country']),
      city: _readString(json, const ['city']),
      state: _readString(json, const ['state', 'province']),
      postalCode: _readString(json, const [
        'pincode',
        'postal_code',
        'zip_code',
        'zip',
      ]),
      isActive: _readBool(json, const ['is_active', 'active']),
    );
  }

  static ContactClientRef _readClient(Map<String, dynamic> json) {
    final raw = json['client'];
    if (raw is Map) {
      return ContactClientRef.fromJson(Map<String, dynamic>.from(raw));
    }
    final flatName = _readString(
      json,
      const ['client_name', 'client'],
    );
    final clientId = raw == null ? '' : raw.toString().trim();
    if (flatName.isEmpty && clientId.isEmpty) return ContactClientRef.empty;
    return ContactClientRef(
      id: clientId,
      name: flatName,
      contactPerson: '',
      email: '',
      phone: '',
    );
  }
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    if (raw is Map || raw is List) continue;
    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') continue;
    return text;
  }
  return fallback;
}

bool _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final t = raw.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
  }
  return false;
}
