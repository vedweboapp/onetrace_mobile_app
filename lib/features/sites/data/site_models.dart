import 'package:flutter/foundation.dart';

@immutable
class SiteModel {
  const SiteModel({
    required this.id,
    required this.siteName,
    required this.clientName,
    this.clientId,
    required this.addressLine1,
    required this.addressLine2,
    required this.country,
    required this.city,
    required this.state,
    required this.postalCode,
    this.isActive = true,
  });

  final String id;
  final String siteName;
  final String clientName;
  final int? clientId;
  final String addressLine1;
  final String addressLine2;
  final String country;
  final String city;
  final String state;
  final String postalCode;
  final bool isActive;

  static SiteModel fromJson(Map<String, dynamic> json) {
    String read(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final raw = json[key];
        if (raw == null) continue;
        if (raw is Map) continue;
        final text = raw.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    var clientName = read(const ['client_name'], fallback: 'Client');
    int? clientId;
    final clientRaw = json['client'];
    if (clientRaw is Map) {
      final clientMap = Map<String, dynamic>.from(
        clientRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
      final idRaw = clientMap['id'];
      clientId = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
      final nestedName = clientMap['name']?.toString().trim();
      if (nestedName != null && nestedName.isNotEmpty) {
        clientName = nestedName;
      }
    } else {
      final clientFk = json['client_id'] ?? json['client'];
      if (clientFk is int) {
        clientId = clientFk;
      } else {
        clientId = int.tryParse('${clientFk ?? ''}');
      }
    }

    final idRaw = json['id'];
    final id = idRaw == null ? '' : idRaw.toString();

    return SiteModel(
      id: id,
      siteName: read(const [
        'site_name',
        'name',
        'item_name',
      ], fallback: 'Site Name'),
      clientName: clientName,
      clientId: clientId,
      addressLine1: read(const ['address_line_1', 'address_line1', 'address']),
      addressLine2: read(const ['address_line_2', 'address_line2']),
      country: read(const ['country']),
      city: read(const ['city']),
      state: read(const ['state', 'province']),
      postalCode: read(const ['postal_code', 'pincode', 'zip_code']),
      isActive: _readBool(json['is_active']) ?? true,
    );
  }
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  if (value == null) return null;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
}
