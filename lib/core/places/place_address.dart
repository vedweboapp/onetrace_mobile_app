import 'package:flutter/material.dart';

/// Normalized postal address parsed from Google Place Details.
class PlaceAddress {
  const PlaceAddress({
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.postalCode = '',
  });

  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String postalCode;

  bool get isEmpty =>
      addressLine1.trim().isEmpty &&
      addressLine2.trim().isEmpty &&
      city.trim().isEmpty &&
      state.trim().isEmpty &&
      country.trim().isEmpty &&
      postalCode.trim().isEmpty;
}

class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
}

/// Parses `address_components` from Google Place Details.
PlaceAddress parsePlaceAddressComponents(List<dynamic> components) {
  String? streetNumber;
  String? route;
  String? subpremise;
  String? premise;
  String? locality;
  String? postalTown;
  String? adminArea2;
  String? adminArea1;
  String? country;
  String? postalCode;

  for (final raw in components) {
    if (raw is! Map) continue;
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final types = (map['types'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const <String>[];
    final long = map['long_name']?.toString().trim() ?? '';
    if (long.isEmpty) continue;

    if (types.contains('street_number')) {
      streetNumber = long;
    } else if (types.contains('route')) {
      route = long;
    } else if (types.contains('subpremise')) {
      subpremise = long;
    } else if (types.contains('premise')) {
      premise = long;
    } else if (types.contains('locality')) {
      locality = long;
    } else if (types.contains('postal_town')) {
      postalTown = long;
    } else if (types.contains('administrative_area_level_2')) {
      adminArea2 = long;
    } else if (types.contains('administrative_area_level_1')) {
      adminArea1 = long;
    } else if (types.contains('country')) {
      country = long;
    } else if (types.contains('postal_code')) {
      postalCode = long;
    }
  }

  final line1 = [streetNumber, route]
      .whereType<String>()
      .where((part) => part.trim().isNotEmpty)
      .join(' ')
      .trim();
  final line2 = [subpremise, premise]
      .whereType<String>()
      .where((part) => part.trim().isNotEmpty)
      .join(', ')
      .trim();
  final city = locality ?? postalTown ?? adminArea2 ?? '';

  return PlaceAddress(
    addressLine1: line1,
    addressLine2: line2,
    city: city,
    state: adminArea1 ?? '',
    country: country ?? '',
    postalCode: postalCode ?? '',
  );
}

/// Fills common address controllers from a [PlaceAddress].
void applyPlaceAddress({
  required PlaceAddress place,
  TextEditingController? addressLine2,
  TextEditingController? city,
  TextEditingController? state,
  TextEditingController? postalCode,
  TextEditingController? country,
  void Function(String country)? onCountrySelected,
}) {
  if (addressLine2 != null && place.addressLine2.trim().isNotEmpty) {
    addressLine2.text = place.addressLine2;
  }
  if (city != null && place.city.trim().isNotEmpty) {
    city.text = place.city;
  }
  if (state != null && place.state.trim().isNotEmpty) {
    state.text = place.state;
  }
  if (postalCode != null && place.postalCode.trim().isNotEmpty) {
    postalCode.text = place.postalCode;
  }
  if (place.country.trim().isNotEmpty) {
    if (country != null) {
      country.text = place.country;
    }
    onCountrySelected?.call(place.country);
  }
}

/// Matches a Google country name to a dropdown option when possible.
String? matchCountryOption(String country, List<String> options) {
  final target = country.trim().toLowerCase();
  if (target.isEmpty || options.isEmpty) return null;

  for (final option in options) {
    if (option.trim().toLowerCase() == target) return option;
  }

  const aliases = <String, List<String>>{
    'united states': ['usa', 'us', 'u.s.', 'u.s.a.'],
    'united kingdom': ['uk', 'great britain', 'gb'],
  };

  for (final option in options) {
    final optionLower = option.trim().toLowerCase();
    if (target.contains(optionLower) || optionLower.contains(target)) {
      return option;
    }
    final aliasList = aliases[optionLower];
    if (aliasList != null && aliasList.contains(target)) return option;
  }

  return null;
}
