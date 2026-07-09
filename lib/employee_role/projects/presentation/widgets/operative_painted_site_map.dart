import 'package:flutter/material.dart';
import 'package:red5/employee_role/projects/data/operative_map_geocoder.dart';
import 'package:red5/employee_role/projects/data/operative_map_pin.dart';
import 'package:red5/employee_role/projects/presentation/project_map_page.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_map_marker_art.dart';

enum OperativeMapPinStyle { teardrop, circle }

/// Offline-friendly stylized map — no network tiles required.
class OperativePaintedSiteMap extends StatelessWidget {
  const OperativePaintedSiteMap({
    super.key,
    required this.pins,
    this.selectedPinId,
    this.onPinTap,
    this.onMapBackgroundTap,
    required this.isDark,
    this.pinStyle = OperativeMapPinStyle.teardrop,
  });

  final List<OperativeMapPin> pins;
  final String? selectedPinId;
  final ValueChanged<OperativeMapPin>? onPinTap;
  final VoidCallback? onMapBackgroundTap;
  final bool isDark;
  final OperativeMapPinStyle pinStyle;

  @override
  Widget build(BuildContext context) {
    final bounds = boundsFor(pins);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onMapBackgroundTap,
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(painter: ProjectSiteMapPainter(isDark: isDark)),
            ),
            for (final pin in pins)
              _PaintedMapPin(
                pin: pin,
                normalized: normalizedPoint(pin, bounds),
                canvasSize: canvasSize,
                selected: pin.id == selectedPinId,
                pinStyle: pinStyle,
                onTap: () => onPinTap?.call(pin),
              ),
          ],
        );
      },
    );
  }

  static OperativePaintedMapBounds boundsFor(List<OperativeMapPin> pins) {
    if (pins.isEmpty) {
      final center = OperativeMapGeocoder.defaultCenter;
      return OperativePaintedMapBounds(
        south: center.latitude - 0.01,
        north: center.latitude + 0.01,
        west: center.longitude - 0.01,
        east: center.longitude + 0.01,
      );
    }

    var south = pins.first.position.latitude;
    var north = south;
    var west = pins.first.position.longitude;
    var east = west;

    for (final pin in pins) {
      final lat = pin.position.latitude;
      final lng = pin.position.longitude;
      if (lat < south) south = lat;
      if (lat > north) north = lat;
      if (lng < west) west = lng;
      if (lng > east) east = lng;
    }

    const pad = 0.008;
    return OperativePaintedMapBounds(
      south: south - pad,
      north: north + pad,
      west: west - pad,
      east: east + pad,
    );
  }

  static Offset normalizedPoint(
    OperativeMapPin pin,
    OperativePaintedMapBounds bounds,
  ) {
    final latSpan = bounds.north - bounds.south;
    final lngSpan = bounds.east - bounds.west;
    if (latSpan <= 0 && lngSpan <= 0) {
      return const Offset(0.5, 0.35);
    }

    final x = lngSpan <= 0
        ? 0.5
        : (pin.position.longitude - bounds.west) / lngSpan;
    final y = latSpan <= 0
        ? 0.5
        : 1 - (pin.position.latitude - bounds.south) / latSpan;

    return Offset(x.clamp(0.12, 0.88), y.clamp(0.28, 0.72));
  }

  /// Screen anchor for placing overlays (card above pin).
  static Offset pinOverlayAnchor({
    required OperativeMapPin pin,
    required List<OperativeMapPin> pins,
    required Size mapSize,
    OperativeMapPinStyle pinStyle = OperativeMapPinStyle.teardrop,
  }) {
    final bounds = boundsFor(pins);
    final normalized = normalizedPoint(pin, bounds);
    final x = normalized.dx * mapSize.width;
    final y = normalized.dy * mapSize.height;

    if (pinStyle == OperativeMapPinStyle.circle) {
      return Offset(x, y - 20);
    }
    return Offset(x, y - 54);
  }
}

final class OperativePaintedMapBounds {
  const OperativePaintedMapBounds({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
  });

  final double south;
  final double north;
  final double west;
  final double east;
}

class _PaintedMapPin extends StatelessWidget {
  const _PaintedMapPin({
    required this.pin,
    required this.normalized,
    required this.canvasSize,
    required this.selected,
    required this.onTap,
    required this.pinStyle,
  });

  final OperativeMapPin pin;
  final Offset normalized;
  final Size canvasSize;
  final bool selected;
  final VoidCallback onTap;
  final OperativeMapPinStyle pinStyle;

  @override
  Widget build(BuildContext context) {
    if (pinStyle == OperativeMapPinStyle.circle) {
      const size = 40.0;
      return Positioned(
        left: normalized.dx * canvasSize.width - size / 2,
        top: normalized.dy * canvasSize.height - size / 2,
        child: GestureDetector(
          onTap: onTap,
          child: OperativeMapMarkerArt.circleSitePin(selected: selected),
        ),
      );
    }

    const width = 44.0;
    const height = 54.0;
    return Positioned(
      left: normalized.dx * canvasSize.width - width / 2,
      top: normalized.dy * canvasSize.height - height,
      child: GestureDetector(
        onTap: onTap,
        child: OperativeMapMarkerArt.teardropPin(selected: selected),
      ),
    );
  }
}
