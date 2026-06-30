import 'package:flutter/material.dart';

class VendorAddressModel {
  const VendorAddressModel({
    this.id,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.country,
    required this.pincode,
    this.latitude,
    this.longitude,
    this.isPrimary = false,
  });

  final int? id;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final String? latitude;
  final String? longitude;
  final bool isPrimary;

  String get street {
    final a = addressLine1.trim();
    final b = addressLine2.trim();
    if (a.isEmpty && b.isEmpty) return '—';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a, $b';
  }

  String get fullLine {
    final parts = <String>[
      street,
      city.trim(),
      state.trim(),
      pincode.trim(),
      country.trim(),
    ].where((p) => p.isNotEmpty && p != '—').toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  factory VendorAddressModel.fromJson(Map<String, dynamic> json) {
    return VendorAddressModel(
      id: _readInt(json['id']),
      addressLine1: _readString(json, const ['address_line_1']) ?? '',
      addressLine2: _readString(json, const ['address_line_2']) ?? '',
      city: _readString(json, const ['city']) ?? '',
      state: _readString(json, const ['state']) ?? '',
      country: _readString(json, const ['country']) ?? '',
      pincode: _readString(json, const ['pincode', 'postal_code']) ?? '',
      latitude: _readString(json, const ['latitude']),
      longitude: _readString(json, const ['longitude']),
      isPrimary: _readBool(json['is_primary']) ?? false,
    );
  }

  Map<String, dynamic> toCreateJson() {
    final line1 = addressLine1.trim();
    final line2 = addressLine2.trim();
    return <String, dynamic>{
      'address_line_1': line1,
      'address_line_2': line2,
      'city': city.trim(),
      'state': state.trim(),
      'country': country.trim(),
      'pincode': pincode.trim(),
      if (latitude != null && latitude!.trim().isNotEmpty)
        'latitude': latitude!.trim(),
      if (longitude != null && longitude!.trim().isNotEmpty)
        'longitude': longitude!.trim(),
      'is_primary': isPrimary,
    };
  }

  bool get hasCreateFields {
    return addressLine1.trim().isNotEmpty ||
        addressLine2.trim().isNotEmpty ||
        city.trim().isNotEmpty ||
        state.trim().isNotEmpty ||
        country.trim().isNotEmpty ||
        pincode.trim().isNotEmpty;
  }
}

class VendorModel {
  const VendorModel({
    required this.id,
    required this.name,
    required this.isActive,
    this.email,
    this.phone,
    this.typeId,
    this.typeName,
    this.addresses = const [],
  });

  final String id;
  final String name;
  final bool isActive;
  final String? email;
  final String? phone;
  final int? typeId;
  final String? typeName;
  final List<VendorAddressModel> addresses;

  String get displayContact => email?.trim().isNotEmpty == true
      ? email!.trim()
      : (phone?.trim().isNotEmpty == true ? phone!.trim() : '—');

  String get displayPhone =>
      phone?.trim().isNotEmpty == true ? phone!.trim() : '—';

  VendorAddressModel? get primaryAddress {
    for (final address in addresses) {
      if (address.isPrimary) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final name = (json['name'] ?? '').toString().trim();
    final email = (json['email'] ?? '').toString().trim();
    final phone = (json['phone'] ?? '').toString().trim();

    int? typeId;
    String? typeName;
    final type = json['type'];
    if (type is int) {
      typeId = type;
    } else if (type is Map) {
      typeId = _readInt(type['id']);
      final n = type['name']?.toString().trim();
      if (n != null && n.isNotEmpty) typeName = n;
    }

    final addressesRaw = json['addresses'];
    final addresses = addressesRaw is List
        ? addressesRaw
            .whereType<Map>()
            .map((row) => VendorAddressModel.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .toList(growable: false)
        : const <VendorAddressModel>[];

    return VendorModel(
      id: id.isEmpty ? '0' : id,
      name: name.isEmpty ? 'Vendor' : name,
      isActive: _readBool(json['is_active']) ?? true,
      email: email.isEmpty ? null : email,
      phone: phone.isEmpty ? null : phone,
      typeId: typeId,
      typeName: typeName,
      addresses: addresses,
    );
  }
}

class VendorTypeOption {
  const VendorTypeOption({
    required this.id,
    required this.name,
    this.code,
    this.bgColor,
    this.textColor,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? code;
  final String? bgColor;
  final String? textColor;
  final bool isActive;

  factory VendorTypeOption.fromJson(Map<String, dynamic> json) {
    final id = _readInt(json['id']) ?? 0;
    final name = _readString(json, const [
          'name',
          'vendor_type',
          'type_name',
          'title',
          'label',
        ]) ??
        'Type $id';
    final code = _readString(json, const ['code', 'slug', 'type']);
    final bgColor = _readString(json, const ['bg_color', 'background_color']);
    final textColor = _readString(json, const ['text_color', 'color']);
    return VendorTypeOption(
      id: id,
      name: name,
      code: code,
      bgColor: bgColor,
      textColor: textColor,
      isActive: _readBool(json['is_active']) ?? true,
    );
  }
}

/// Builds `POST /vendor-type/` and `PUT /vendor-type/{id}/` bodies.
abstract final class VendorTypeWritePayload {
  const VendorTypeWritePayload._();

  static Map<String, dynamic> build({
    required String name,
    String? bgColor,
    String? textColor,
    bool isActive = true,
  }) {
    return <String, dynamic>{
      'name': name.trim(),
      if (bgColor != null && bgColor.trim().isNotEmpty)
        'bg_color': bgColor.trim(),
      if (textColor != null && textColor.trim().isNotEmpty)
        'text_color': textColor.trim(),
      'is_active': isActive,
    };
  }
}

/// Builds `POST /vendors/` bodies matching the backend contract.
abstract final class VendorWritePayload {
  const VendorWritePayload._();

  static Map<String, dynamic> build({
    required String name,
    required String email,
    String? phone,
    required int type,
    required List<VendorAddressModel> addresses,
  }) {
    final addressPayload = addresses
        .where((address) => address.hasCreateFields)
        .map((address) => address.toCreateJson())
        .toList(growable: false);

    return <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'type': type,
      'addresses': addressPayload,
    };
  }
}

Color vendorStatusBg(bool active) =>
    active ? const Color(0xFFE9F9EE) : const Color(0xFFF1F1F2);

Color vendorStatusFg(bool active) =>
    active ? const Color(0xFF137333) : const Color(0xFF6B6B70);

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}'.trim());
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  if (value == null) return null;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
}
