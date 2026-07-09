import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

final operativeMapRouteServiceProvider = Provider<OperativeMapRouteService>(
  (ref) => OperativeMapRouteService(),
);

final class OperativeRoutePlan {
  const OperativeRoutePlan({
    required this.origin,
    required this.destination,
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.destinationTitle,
    this.destinationSubtitle,
    this.isEstimated = false,
  });

  final ll.LatLng origin;
  final ll.LatLng destination;
  final List<ll.LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;
  final String destinationTitle;
  final String? destinationSubtitle;
  final bool isEstimated;

  String get distanceLabel {
    final miles = distanceMeters / 1609.344;
    if (miles < 0.1) return '${(distanceMeters).round()} m';
    return '${miles.toStringAsFixed(1)} mi';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
  }
}

/// Fetches operative GPS + driving route (OSRM) for Rapido-style navigation.
final class OperativeMapRouteService {
  OperativeMapRouteService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
            ),
          );

  final Dio _dio;
  static const _distance = ll.Distance();

  Future<ll.LatLng?> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return ll.LatLng(position.latitude, position.longitude);
  }

  Future<OperativeRoutePlan> buildRoute({
    required ll.LatLng destination,
    required String destinationTitle,
    String? destinationSubtitle,
    ll.LatLng? origin,
  }) async {
    final start = origin ?? await currentLocation();
    final effectiveOrigin = start ?? _fallbackOriginNear(destination);

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://router.project-osrm.org/route/v1/driving/'
        '${effectiveOrigin.longitude},${effectiveOrigin.latitude};'
        '${destination.longitude},${destination.latitude}',
        queryParameters: const {'overview': 'full', 'geometries': 'geojson'},
      );
      final data = response.data;
      final routes = data?['routes'];
      if (routes is List && routes.isNotEmpty) {
        final route = Map<String, dynamic>.from(routes.first as Map);
        final geometry = Map<String, dynamic>.from(route['geometry'] as Map);
        final coords = geometry['coordinates'];
        final points = <ll.LatLng>[];
        if (coords is List) {
          for (final coord in coords) {
            if (coord is List && coord.length >= 2) {
              points.add(
                ll.LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                ),
              );
            }
          }
        }
        if (points.isNotEmpty) {
          return OperativeRoutePlan(
            origin: effectiveOrigin,
            destination: destination,
            polyline: points,
            distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
            durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
            destinationTitle: destinationTitle,
            destinationSubtitle: destinationSubtitle,
            isEstimated: start == null,
          );
        }
      }
    } catch (_) {
      // Fall through to straight-line estimate.
    }

    return _straightLineRoute(
      origin: effectiveOrigin,
      destination: destination,
      destinationTitle: destinationTitle,
      destinationSubtitle: destinationSubtitle,
      isEstimated: true,
    );
  }

  OperativeRoutePlan _straightLineRoute({
    required ll.LatLng origin,
    required ll.LatLng destination,
    required String destinationTitle,
    String? destinationSubtitle,
    bool isEstimated = false,
  }) {
    final meters = _distance.as(ll.LengthUnit.Meter, origin, destination);
    const avgDrivingMps = 11.1; // ~25 mph
    return OperativeRoutePlan(
      origin: origin,
      destination: destination,
      polyline: [origin, destination],
      distanceMeters: meters,
      durationSeconds: meters / avgDrivingMps,
      destinationTitle: destinationTitle,
      destinationSubtitle: destinationSubtitle,
      isEstimated: isEstimated,
    );
  }

  ll.LatLng _fallbackOriginNear(ll.LatLng destination) {
    return ll.LatLng(
      destination.latitude - 0.018,
      destination.longitude - 0.012,
    );
  }

  static ll.LatLng toLatLong(LatLng google) {
    return ll.LatLng(google.latitude, google.longitude);
  }
}
