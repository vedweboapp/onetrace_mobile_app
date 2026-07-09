import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:red5/core/config/google_places_config.dart';

final operativeMapGeocoderProvider = Provider<OperativeMapGeocoder>(
  (ref) => OperativeMapGeocoder(),
);

/// Resolves site addresses to map coordinates (cached in memory).
final class OperativeMapGeocoder {
  OperativeMapGeocoder({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://maps.googleapis.com/maps/api',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  final Dio _dio;
  final _cache = <String, LatLng>{};

  static const defaultCenter = LatLng(51.5074, -0.1278);

  Future<LatLng> resolve({
    required String address,
    required int stableId,
    int index = 0,
  }) async {
    final key = address.trim().toLowerCase();
    if (key.isEmpty) {
      return _fallbackPosition(stableId, index: index);
    }
    final cached = _cache[key];
    if (cached != null) return cached;

    if (!GooglePlacesConfig.isConfigured) {
      final fallback = _fallbackPosition(stableId, index: index);
      _cache[key] = fallback;
      return fallback;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/geocode/json',
        queryParameters: <String, dynamic>{
          'address': address,
          'key': GooglePlacesConfig.apiKey,
          'region': 'gb',
        },
      );
      final data = response.data;
      final results = data?['results'];
      if (results is List && results.isNotEmpty) {
        final first = results.first;
        if (first is Map) {
          final geometry = first['geometry'];
          if (geometry is Map) {
            final location = geometry['location'];
            if (location is Map) {
              final lat = _readDouble(location['lat']);
              final lng = _readDouble(location['lng']);
              if (lat != null && lng != null) {
                final point = LatLng(lat, lng);
                _cache[key] = point;
                return point;
              }
            }
          }
        }
      }
    } catch (_) {}

    final fallback = _fallbackPosition(stableId, index: index);
    _cache[key] = fallback;
    return fallback;
  }

  LatLng _fallbackPosition(int stableId, {int index = 0}) {
    final angle = ((stableId * 137.508) + (index * 47.0)) % 360;
    final radians = angle * math.pi / 180;
    final ring = 0.006 + (index % 3) * 0.0035;
    return LatLng(
      defaultCenter.latitude + ring * math.cos(radians),
      defaultCenter.longitude + ring * math.sin(radians),
    );
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
