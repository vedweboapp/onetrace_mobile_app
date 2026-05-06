import 'package:flutter/foundation.dart';

@immutable
class ClientModel {
  const ClientModel({
    required this.id,
    required this.createdAt,
    required this.modifiedAt,
    required this.name,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.country,
    required this.pincode,
    required this.isActive,
  });

  final String id;
  final String createdAt;
  final String modifiedAt;
  final String name;
  final String contactPerson;
  final String email;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final bool isActive;

  static ClientModel fromJson(Map<String, dynamic> json) {
    String read(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        final text = raw.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    bool readBool(List<String> keys, {bool fallback = true}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw is bool) return raw;
        if (raw is String) {
          final t = raw.trim().toLowerCase();
          if (t == 'true' || t == '1') return true;
          if (t == 'false' || t == '0') return false;
        }
        if (raw is num) return raw != 0;
      }
      return fallback;
    }

    return ClientModel(
      id: read(const ['id']),
      createdAt: read(const ['created_at']),
      modifiedAt: read(const ['modified_at']),
      name: read(const ['name']),
      contactPerson: read(const ['contact_person']),
      email: read(const ['email']),
      phone: read(const ['phone']),
      addressLine1: read(const ['address_line_1']),
      addressLine2: read(const ['address_line_2']),
      city: read(const ['city']),
      state: read(const ['state']),
      country: read(const ['country']),
      pincode: read(const ['pincode']),
      isActive: readBool(const ['is_active'], fallback: true),
    );
  }

  ClientModel copyWith({
    String? id,
    String? createdAt,
    String? modifiedAt,
    String? name,
    String? contactPerson,
    String? email,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? country,
    String? pincode,
    bool? isActive,
  }) {
    return ClientModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      isActive: isActive ?? this.isActive,
    );
  }
}

