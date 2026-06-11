import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/sites/data/site_models.dart';

final class ProjectMapJob {
  const ProjectMapJob({
    required this.id,
    required this.title,
    required this.address,
    required this.status,
    required this.position,
    required this.distanceMiles,
    this.isActive = false,
  });

  final int id;
  final String title;
  final String address;
  final String status;
  final LatLng position;
  final double distanceMiles;
  final bool isActive;

  String get markerId => 'job-$id';

  String get distanceLabel => '${distanceMiles.toStringAsFixed(1)} mi';

  ProjectMapJob copyWith({
    String? title,
    String? address,
    String? status,
    LatLng? position,
    double? distanceMiles,
    bool? isActive,
  }) {
    return ProjectMapJob(
      id: id,
      title: title ?? this.title,
      address: address ?? this.address,
      status: status ?? this.status,
      position: position ?? this.position,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      isActive: isActive ?? this.isActive,
    );
  }

  static ProjectMapJob fromSite(SiteModel site) {
    final address = [
      site.addressLine1,
      site.addressLine2,
      site.city,
      site.state,
      site.postalCode,
    ].where((part) => part.trim().isNotEmpty).join(', ');

    final id = int.tryParse(site.id) ?? site.id.hashCode;

    return ProjectMapJob(
      id: id,
      title: site.siteName,
      address: address.isEmpty ? site.clientName : address,
      status: site.isActive ? 'ACTIVE' : 'INACTIVE',
      position: const LatLng(0, 0),
      distanceMiles: 0,
      isActive: site.isActive,
    );
  }

  static ProjectMapJob? fromJobRead(JobRead job) {
    final latitude =
        _readCoordinate(job.jobMeta, const [
          'latitude',
          'lat',
          'job_latitude',
        ]) ??
        _validLatitude(job.pinXCoordinate);
    final longitude =
        _readCoordinate(job.jobMeta, const [
          'longitude',
          'lng',
          'lon',
          'job_longitude',
        ]) ??
        _validLongitude(job.pinYCoordinate);
    if (latitude == null || longitude == null) return null;

    return ProjectMapJob(
      id: job.id,
      title: job.title,
      address: job.displayLocation,
      status: job.displayStatus.toUpperCase(),
      position: LatLng(latitude, longitude),
      distanceMiles: _readDouble(job.jobMeta['distance_miles']) ?? 0.0,
      isActive: job.completedAt == null,
    );
  }

  static double? _readCoordinate(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = _readDouble(map[key]);
      if (value != null) return value;
    }
    final location = map['location'];
    if (location is Map) {
      return _readCoordinate(Map<String, dynamic>.from(location), keys);
    }
    return null;
  }

  static double? _validLatitude(double? value) {
    if (value == null || value < -90 || value > 90) return null;
    return value;
  }

  static double? _validLongitude(double? value) {
    if (value == null || value < -180 || value > 180) return null;
    return value;
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString().trim());
  }
}
