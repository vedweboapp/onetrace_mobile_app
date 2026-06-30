import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/config/google_places_config.dart';
import 'package:red5/core/places/place_address.dart';

final class GooglePlacesService {
  GooglePlacesService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://maps.googleapis.com/maps/api',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
              ),
            );

  final Dio _dio;

  Future<List<PlacePrediction>> fetchPredictions(String input) async {
    final query = input.trim();
    if (query.length < 2) return const [];

    final response = await _dio.get<Map<String, dynamic>>(
      '/place/autocomplete/json',
      queryParameters: <String, dynamic>{
        'input': query,
        'key': GooglePlacesConfig.apiKey,
        'language': GooglePlacesConfig.language,
        'types': 'address',
      },
    );

    final data = response.data;
    if (data == null || data['status'] != 'OK') return const [];

    final predictions = data['predictions'];
    if (predictions is! List) return const [];

    return predictions
        .whereType<Map>()
        .map((raw) {
          final map = raw.map((k, v) => MapEntry(k.toString(), v));
          final placeId = map['place_id']?.toString().trim() ?? '';
          final description = map['description']?.toString().trim() ?? '';
          if (placeId.isEmpty || description.isEmpty) return null;

          final structured = map['structured_formatting'];
          String mainText = description;
          String secondaryText = '';
          if (structured is Map) {
            final mainRaw = structured['main_text']?.toString().trim() ?? '';
            mainText = mainRaw.isNotEmpty ? mainRaw : description;
            secondaryText = structured['secondary_text']?.toString().trim() ?? '';
          }

          return PlacePrediction(
            placeId: placeId,
            description: description,
            mainText: mainText,
            secondaryText: secondaryText,
          );
        })
        .whereType<PlacePrediction>()
        .toList(growable: false);
  }

  Future<PlaceAddress> fetchPlaceAddress(String placeId) async {
    final id = placeId.trim();
    if (id.isEmpty) return const PlaceAddress();

    final response = await _dio.get<Map<String, dynamic>>(
      '/place/details/json',
      queryParameters: <String, dynamic>{
        'place_id': id,
        'key': GooglePlacesConfig.apiKey,
        'language': GooglePlacesConfig.language,
        'fields': 'address_component,formatted_address',
      },
    );

    final data = response.data;
    if (data == null || data['status'] != 'OK') return const PlaceAddress();

    final result = data['result'];
    if (result is! Map) return const PlaceAddress();
    final map = result.map((k, v) => MapEntry(k.toString(), v));

    final components = map['address_components'];
    if (components is List && components.isNotEmpty) {
      final parsed = parsePlaceAddressComponents(components);
      if (!parsed.isEmpty) return parsed;
    }

    final formatted = map['formatted_address']?.toString().trim() ?? '';
    if (formatted.isEmpty) return const PlaceAddress();
    return PlaceAddress(addressLine1: formatted);
  }
}

final googlePlacesServiceProvider = Provider<GooglePlacesService>(
  (ref) => GooglePlacesService(),
);
