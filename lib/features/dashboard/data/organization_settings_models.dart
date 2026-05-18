import 'package:flutter/foundation.dart';

/// Company / organization settings from `GET /organizationsettings/{id}/`.
@immutable
class OrganizationSettingsModel {
  const OrganizationSettingsModel({
    required this.id,
    required this.uuid,
    required this.companyName,
    required this.companySize,
    required this.companyLogo,
    required this.websiteLink,
    required this.description,
    required this.timezone,
    required this.startTime,
    required this.endTime,
    required this.streetAddress,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,
    required this.currency,
    required this.format,
    required this.symbol,
    required this.symbolPosition,
    required this.digitSeparator,
    required this.decimalPlaces,
    required this.workingDays,
    required this.breakDuration,
  });

  final int id;
  final String uuid;
  final String companyName;
  final String companySize;
  final String companyLogo;
  final String websiteLink;
  final String description;
  final String timezone;
  final String startTime;
  final String endTime;
  final String streetAddress;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final String currency;
  final String format;
  final String symbol;
  final String symbolPosition;
  final String digitSeparator;
  final int? decimalPlaces;
  final List<String> workingDays;
  final String breakDuration;

  factory OrganizationSettingsModel.fromJson(Map<String, dynamic> json) {
    return OrganizationSettingsModel(
      id: _readInt(json, const ['id']) ?? 0,
      uuid: _readString(json, const ['uuid']),
      companyName: _readString(json, const ['company_name', 'companyName']),
      companySize: _readString(json, const ['company_size', 'companySize']),
      companyLogo: _readString(json, const ['company_logo', 'companyLogo']),
      websiteLink: _readString(json, const ['website_link', 'websiteLink']),
      description: _readString(json, const ['description']),
      timezone: _readString(json, const ['timezone']),
      startTime: _readString(json, const ['start_time', 'startTime']),
      endTime: _readString(json, const ['end_time', 'endTime']),
      streetAddress: _readString(json, const [
        'street_address',
        'streetAddress',
      ]),
      city: _readString(json, const ['city']),
      state: _readString(json, const ['state']),
      pincode: _readString(json, const ['pincode', 'postal_code']),
      country: _readString(json, const ['country']),
      currency: _readString(json, const ['currency']),
      format: _readString(json, const ['format']),
      symbol: _readString(json, const ['symbol']),
      symbolPosition: _readString(json, const [
        'symbol_position',
        'symbolPosition',
      ]),
      digitSeparator: _readString(json, const [
        'digit_separator',
        'digitSeparator',
      ]),
      decimalPlaces: _readInt(json, const ['decimal_places', 'decimalPlaces']),
      workingDays: _readStringList(json['working_days'] ?? json['workingDays']),
      breakDuration: _readString(json, const [
        'break_duration',
        'breakDuration',
      ]),
    );
  }
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e?.toString().trim() ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}

String _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return '';
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final v = json[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
  }
  return null;
}
