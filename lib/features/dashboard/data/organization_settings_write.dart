import 'package:flutter/foundation.dart';
import 'package:red5/features/dashboard/data/organization_settings_codec.dart';

/// Request body for `PUT /organizationsettings/{organizationId}/`.
@immutable
class OrganizationSettingsWrite {
  const OrganizationSettingsWrite({
    required this.companyName,
    this.companySize,
    this.websiteLink,
    this.description,
    this.timezone,
    this.streetAddress,
    this.city,
    this.state,
    this.pincode,
    this.country,
    required this.workingDays,
    this.startTime,
    this.endTime,
    this.breakDuration,
    this.currency,
    this.format,
    this.symbol,
    this.symbolPosition,
    this.digitSeparator,
    this.decimalPlaces,
  });

  final String companyName;
  final String? companySize;
  final String? websiteLink;
  final String? description;
  final String? timezone;
  final String? streetAddress;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;

  /// Full day names, e.g. `Monday`, `Tuesday` (Django `WorkingDaysChoices`).
  final List<String> workingDays;
  final String? startTime;
  final String? endTime;
  /// Break length as `hh:mm:ss` (Django `TimeField`).
  final String? breakDuration;
  final String? currency;
  final String? format;
  final String? symbol;
  final String? symbolPosition;
  final String? digitSeparator;
  final int? decimalPlaces;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'company_name': companyName,
      'company_size': _nullIfEmpty(companySize),
      'website_link': _nullIfEmpty(websiteLink),
      'description': _nullIfEmpty(description),
      'timezone': _nullIfEmpty(timezone),
      'street_address': _nullIfEmpty(streetAddress),
      'city': _nullIfEmpty(city),
      'state': _nullIfEmpty(state),
      'pincode': _nullIfEmpty(pincode),
      'country': _nullIfEmpty(country),
      'working_days': OrganizationSettingsCodec.workingDaysToApi(workingDays),
      if (startTime != null && startTime!.isNotEmpty) 'start_time': startTime,
      if (endTime != null && endTime!.isNotEmpty) 'end_time': endTime,
      if (breakDuration != null && breakDuration!.isNotEmpty)
        'break_duration': breakDuration,
      if (currency != null && currency!.isNotEmpty) 'currency': currency,
      if (format != null && format!.isNotEmpty) 'format': format,
      if (symbol != null && symbol!.isNotEmpty) 'symbol': symbol,
      if (symbolPosition != null && symbolPosition!.isNotEmpty)
        'symbol_position': symbolPosition,
      if (digitSeparator != null && digitSeparator!.isNotEmpty)
        'digit_separator':
            OrganizationSettingsCodec.digitSeparatorToApi(digitSeparator!),
      if (decimalPlaces != null) 'decimal_places': decimalPlaces,
    };
  }

  static String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Canonical weekday labels for API `working_days`.
abstract final class WorkingDaysChoices {
  const WorkingDaysChoices._();

  static const monday = 'Monday';
  static const tuesday = 'Tuesday';
  static const wednesday = 'Wednesday';
  static const thursday = 'Thursday';
  static const friday = 'Friday';
  static const saturday = 'Saturday';
  static const sunday = 'Sunday';

  static const all = <String>[
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
  ];
}
