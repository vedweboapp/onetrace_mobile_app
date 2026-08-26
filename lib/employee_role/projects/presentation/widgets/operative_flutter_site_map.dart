import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:latlong2/latlong.dart' as ll;
import 'package:red5/core/maps/app_map_tiles.dart';
import 'package:red5/employee_role/projects/data/operative_map_pin.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_map_marker_art.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_painted_site_map.dart';

/// Online tile map (Carto OSM basemap) — no Google Maps SDK / JS key required.
class OperativeFlutterSiteMap extends StatefulWidget {
  const OperativeFlutterSiteMap({
    super.key,
    required this.pins,
    this.selectedPinId,
    this.routePoints = const [],
    this.routeOrigin,
    this.initialCenter = const LatLng(51.5074, -0.1278),
    this.initialZoom = 12.5,
    this.onPinTap,
    this.onMapTap,
    this.onMapReady,
    this.onSelectedPinScreen,
    this.controller,
    this.pinStyle = OperativeMapPinStyle.teardrop,
    this.isDark = false,
  });

  final List<OperativeMapPin> pins;
  final String? selectedPinId;
  final List<LatLng> routePoints;
  final LatLng? routeOrigin;
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<OperativeMapPin>? onPinTap;
  final VoidCallback? onMapTap;
  final VoidCallback? onMapReady;
  final ValueChanged<Offset?>? onSelectedPinScreen;
  final OperativeFlutterSiteMapController? controller;
  final OperativeMapPinStyle pinStyle;
  final bool isDark;

  @override
  State<OperativeFlutterSiteMap> createState() =>
      _OperativeFlutterSiteMapState();
}

class OperativeFlutterSiteMapController {
  _OperativeFlutterSiteMapState? _state;

  void _attach(_OperativeFlutterSiteMapState state) => _state = state;

  void _detach(_OperativeFlutterSiteMapState state) {
    if (identical(_state, state)) _state = null;
  }

  Future<void> fitPins() async => _state?._fitPins();

  Future<void> fitRoute() async => _state?._fitRoute();

  Future<void> recenter(LatLng target, {double zoom = 15}) async =>
      _state?._recenter(target, zoom: zoom);

  Future<void> refreshSelectedPinScreen() async =>
      _state?._emitSelectedPinScreen();
}

class _OperativeFlutterSiteMapState extends State<OperativeFlutterSiteMap> {
  late final MapController _mapController;
  var _readyNotified = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    widget.controller?._attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_readyNotified) {
        _readyNotified = true;
        widget.onMapReady?.call();
      }
      _fitInitial();
      _emitSelectedPinScreen();
    });
  }

  @override
  void didUpdateWidget(covariant OperativeFlutterSiteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }

    final pinsChanged = oldWidget.pins != widget.pins;
    final routeChanged = oldWidget.routePoints != widget.routePoints ||
        oldWidget.routeOrigin != widget.routeOrigin;
    final selectionChanged = oldWidget.selectedPinId != widget.selectedPinId;

    if (pinsChanged && widget.routePoints.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitPins());
    }
    if (routeChanged && widget.routePoints.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    }
    if (selectionChanged || pinsChanged || routeChanged) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _emitSelectedPinScreen(),
      );
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _mapController.dispose();
    super.dispose();
  }

  ll.LatLng _toLl(LatLng p) => ll.LatLng(p.latitude, p.longitude);

  void _fitInitial() {
    if (widget.routePoints.length >= 2) {
      _fitRoute();
    } else {
      _fitPins();
    }
  }

  void _fitPins() {
    final pins = widget.pins;
    if (pins.isEmpty) {
      _mapController.move(_toLl(widget.initialCenter), widget.initialZoom);
      return;
    }
    if (pins.length == 1) {
      _mapController.move(_toLl(pins.first.position), 14.5);
      return;
    }
    final points = [for (final p in pins) _toLl(p.position)];
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
    );
  }

  void _fitRoute() {
    final points = <ll.LatLng>[
      for (final p in widget.routePoints) _toLl(p),
      if (widget.routeOrigin != null) _toLl(widget.routeOrigin!),
      for (final p in widget.pins) _toLl(p.position),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 14);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  void _recenter(LatLng target, {required double zoom}) {
    _mapController.move(_toLl(target), zoom);
  }

  void _emitSelectedPinScreen() {
    final id = widget.selectedPinId;
    if (id == null) {
      widget.onSelectedPinScreen?.call(null);
      return;
    }
    OperativeMapPin? pin;
    for (final p in widget.pins) {
      if (p.id == id) {
        pin = p;
        break;
      }
    }
    if (pin == null) {
      widget.onSelectedPinScreen?.call(null);
      return;
    }
    try {
      final camera = _mapController.camera;
      final offset = camera.latLngToScreenOffset(_toLl(pin.position));
      final yPad = widget.pinStyle == OperativeMapPinStyle.circle ? 22.0 : 56.0;
      widget.onSelectedPinScreen?.call(
        Offset(offset.dx, offset.dy - yPad),
      );
    } catch (_) {
      widget.onSelectedPinScreen?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = [
      for (final p in widget.routePoints) _toLl(p),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _toLl(widget.initialCenter),
        initialZoom: widget.initialZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, _) => widget.onMapTap?.call(),
        onMapEvent: (event) {
          if (event is MapEventMove ||
              event is MapEventMoveEnd ||
              event is MapEventFlingAnimationEnd) {
            _emitSelectedPinScreen();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: widget.isDark
              ? AppMapTiles.darkUrlTemplate
              : AppMapTiles.lightUrlTemplate,
          fallbackUrl: AppMapTiles.fallbackUrlTemplate,
          subdomains: AppMapTiles.subdomains,
          userAgentPackageName: AppMapTiles.userAgentPackageName,
          maxNativeZoom: 19,
          // Avoid flooding the debug console when a tile briefly fails.
          errorTileCallback: (_, error, stackTrace) {},
        ),
        if (routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 5,
                color: const Color(0xFF00A553),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.routeOrigin != null)
              Marker(
                point: _toLl(widget.routeOrigin!),
                width: 26,
                height: 26,
                child: OperativeMapMarkerArt.userLocationDot(),
              ),
            for (final pin in widget.pins)
              Marker(
                point: _toLl(pin.position),
                width: pin.id == widget.selectedPinId ? 44 : 36,
                height: pin.id == widget.selectedPinId ? 58 : 48,
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () => widget.onPinTap?.call(pin),
                  child: widget.pinStyle == OperativeMapPinStyle.circle
                      ? OperativeMapMarkerArt.circleSitePin(
                          selected: pin.id == widget.selectedPinId,
                        )
                      : OperativeMapMarkerArt.teardropPin(
                          selected: pin.id == widget.selectedPinId,
                          width: pin.id == widget.selectedPinId ? 44 : 36,
                        ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
