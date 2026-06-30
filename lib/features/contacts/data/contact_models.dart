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
    this.contactType,
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
  final String? contactType;

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
    final merged = _mergeContactJson(json);
    return ContactModel(
      id: _readString(merged, const ['id']),
      contactName: _readString(
        merged,
        const ['name', 'contact_name', 'full_name'],
        fallback: 'Contact Name',
      ),
      client: _readClient(merged),
      email: _readString(merged, const ['email', 'email_address']),
      phone: _readString(merged, const ['phone', 'phone_number', 'mobile']),
      addressLine1: _readString(merged, const [
        'address_line_1',
        'address_line1',
        'address_1',
        'address',
      ]),
      addressLine2: _readString(merged, const [
        'address_line_2',
        'address_line2',
        'address_2',
      ]),
      country: _readString(merged, const ['country']),
      city: _readString(merged, const ['city']),
      state: _readString(merged, const ['state', 'province']),
      postalCode: _readString(merged, const [
        'pincode',
        'postal_code',
        'post_code',
        'zip_code',
        'zip',
      ]),
      isActive: _readBool(merged, const ['is_active', 'active']),
      contactType: _readString(merged, const ['contact_type', 'type']),
    );
  }

  /// Flatten nested `contact`, `address`, or `addresses[]` shapes from detail APIs.
  static Map<String, dynamic> _mergeContactJson(Map<String, dynamic> json) {
    final merged = Map<String, dynamic>.from(json);

    for (final key in const ['contact', 'contact_detail']) {
      final raw = json[key];
      if (raw is Map) {
        _overlayContactFields(merged, Map<String, dynamic>.from(raw));
        break;
      }
    }

    final address = merged['address'];
    if (address is Map) {
      _overlayContactFields(merged, Map<String, dynamic>.from(address));
    }

    final addresses = merged['addresses'];
    if (addresses is List && addresses.isNotEmpty) {
      Map<String, dynamic>? picked;
      for (final entry in addresses) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(
          entry.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (_readBool(map, const ['is_primary', 'primary'])) {
          picked = map;
          break;
        }
        picked ??= map;
      }
      if (picked != null) {
        _overlayContactFields(merged, picked);
      }
    }

    return merged;
  }

  static void _overlayContactFields(
    Map<String, dynamic> target,
    Map<String, dynamic> overlay,
  ) {
    for (final entry in overlay.entries) {
      final value = entry.value;
      if (value == null) continue;
      final existing = target[entry.key];
      if (existing == null ||
          (existing is String && existing.trim().isEmpty)) {
        target[entry.key] = value;
      }
    }
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

/// API values for `contact_type` on `/contact/` create/update.
abstract final class ContactTypeValues {
  ContactTypeValues._();

  static const client = 'client';
  static const vendor = 'vendor';

  static const options = <({String value, String label})>[
    (value: client, label: 'Client'),
    (value: vendor, label: 'Vendor'),
  ];

  static String labelFor(String? value) {
    final normalized = normalize(value);
    if (normalized == client) return 'Client';
    if (normalized == vendor) return 'Vendor';
    return value?.trim().isNotEmpty == true ? value!.trim() : 'Client';
  }

  static String? normalize(String? value) {
    final t = value?.trim().toLowerCase();
    if (t == client || t == vendor) return t;
    return null;
  }
}
