import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A pin shown on the operative ride-style map.
@immutable
final class OperativeMapPin {
  const OperativeMapPin({
    required this.id,
    required this.title,
    required this.position,
    this.subtitle,
  });

  final String id;
  final String title;
  final LatLng position;
  final String? subtitle;
}
