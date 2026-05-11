import 'package:flutter/foundation.dart';

@immutable
class SiteModel {
  const SiteModel({
    required this.id,
    required this.siteName,
    required this.clientName,
    required this.addressLine1,
    required this.addressLine2,
    required this.country,
    required this.city,
    required this.state,
    required this.postalCode,
  });

  final String id;
  final String siteName;
  final String clientName;
  final String addressLine1;
  final String addressLine2;
  final String country;
  final String city;
  final String state;
  final String postalCode;

  static SiteModel fromJson(Map<String, dynamic> json) {
    String read(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        final text = raw.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    return SiteModel(
      id: read(const ['id']),
      siteName: read(const [
        'site_name',
        'name',
        'item_name',
      ], fallback: 'Site Name'),
      clientName: read(const ['client_name', 'client'], fallback: 'Client'),
      addressLine1: read(const ['address_line_1', 'address_line1', 'address']),
      addressLine2: read(const ['address_line_2', 'address_line2']),
      country: read(const ['country']),
      city: read(const ['city']),
      state: read(const ['state', 'province']),
      postalCode: read(const ['postal_code', 'pincode', 'zip_code']),
    );
  }
}
