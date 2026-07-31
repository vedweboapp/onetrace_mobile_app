import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    if (!GooglePlacesConfig.isConfigured) {
      assert(() {
        debugPrint(
          'Google Places: missing GOOGLE_MAPS_API_KEY '
          '(use --dart-define-from-file=dart_defines.json).',
        );
        return true;
      }());
      return const [];
    }

    try {
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
      final status = data?['status']?.toString();
      if (data == null || status != 'OK') {
        _logPlacesStatus('autocomplete', status, data?['error_message']);
        return const [];
      }

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
              secondaryText =
                  structured['secondary_text']?.toString().trim() ?? '';
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
    } on DioException catch (error, stackTrace) {
      debugPrint('Google Places autocomplete failed: $error');
      debugPrint('$stackTrace');
      return const [];
    }
  }

  Future<PlaceAddress> fetchPlaceAddress(String placeId) async {
    final id = placeId.trim();
    if (id.isEmpty) return const PlaceAddress();
    if (!GooglePlacesConfig.isConfigured) return const PlaceAddress();

    try {
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
      final status = data?['status']?.toString();
      if (data == null || status != 'OK') {
        _logPlacesStatus('details', status, data?['error_message']);
        return const PlaceAddress();
      }

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
    } on DioException catch (error, stackTrace) {
      debugPrint('Google Places details failed: $error');
      debugPrint('$stackTrace');
      return const PlaceAddress();
    }
  }

  void _logPlacesStatus(String endpoint, String? status, dynamic message) {
    if (status == null || status == 'ZERO_RESULTS') return;
    debugPrint(
      'Google Places $endpoint: $status'
      '${message == null ? '' : ' — $message'}',
    );
  }
}

final googlePlacesServiceProvider = Provider<GooglePlacesService>(
  (ref) => GooglePlacesService(),
);

