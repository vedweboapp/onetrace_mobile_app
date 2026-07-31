import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';
import 'package:red5/employee_role/projects/data/operative_map_geocoder.dart';
import 'package:red5/employee_role/projects/data/operative_map_pin.dart';
import 'package:red5/employee_role/projects/data/operative_map_route_service.dart';
import 'package:red5/employee_role/projects/data/operative_map_pins_cache.dart';
import 'package:red5/employee_role/projects/data/project_map_job.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_map_pin_action_card.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_map_marker_art.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_route_bottom_card.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_painted_site_map.dart';
import 'package:red5/employee_role/projects/presentation/widgets/project_map_overlays.dart';

/// Ride-hailing style map for operative site views.
/// Uses Google Maps when online; falls back to painted map offline.
class OperativeSiteGoogleMap extends ConsumerStatefulWidget {
  const OperativeSiteGoogleMap({
    super.key,
    required this.pins,
    this.selectedPinId,
    this.onPinTap,
    this.onDrawings,
    this.onShowRoutes,
    this.onClearSelection,
    this.routePinId,
    this.onExitRoute,
    this.onOpenExternalNavigation,
    this.borderRadius = 16,
    this.isDark = false,
    this.onToggleTheme,
    this.showFloatingControls = true,
    this.isLoading = false,
    this.embedded = false,
    this.pinStyle = OperativeMapPinStyle.teardrop,
  });

  final List<OperativeMapPin> pins;
  final String? selectedPinId;
  final ValueChanged<OperativeMapPin>? onPinTap;
  final VoidCallback? onDrawings;
  final VoidCallback? onShowRoutes;
  final VoidCallback? onClearSelection;
  final String? routePinId;
  final VoidCallback? onExitRoute;
  final VoidCallback? onOpenExternalNavigation;
  final double borderRadius;
  final bool isDark;
  final VoidCallback? onToggleTheme;
  final bool showFloatingControls;
  final bool isLoading;
  final bool embedded;
  final OperativeMapPinStyle pinStyle;

  @override
  ConsumerState<OperativeSiteGoogleMap> createState() =>
      _OperativeSiteGoogleMapState();
}

class _OperativeSiteGoogleMapState
    extends ConsumerState<OperativeSiteGoogleMap> {
  static const _mapLoadTimeout = Duration(seconds: 30);

  GoogleMapController? _googleMapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _pinIcon;
  BitmapDescriptor? _pinSelectedIcon;
  BitmapDescriptor? _userDotIcon;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _mapLoadTimeoutTimer;
  var _isOnline = true;
  var _mapReady = false;
  var _loadTimedOut = false;
  var _cameraTick = 0;
  Offset? _selectedPinScreen;
  OperativeRoutePlan? _routePlan;
  var _loadingRoute = false;

  bool get _useNetworkTiles => _isOnline;

  bool get _usePaintedFallback => !_isOnline;

  /// Keep GoogleMap mounted under the loader so [onMapCreated] can fire.
  bool get _showMapLoader {
    if (_loadTimedOut) return false;
    if (widget.isLoading) return true;
    if (_useNetworkTiles && !_mapReady) return true;
    return false;
  }

  void _startMapLoadTimeout() {
    _mapLoadTimeoutTimer?.cancel();
    _mapLoadTimeoutTimer = Timer(_mapLoadTimeout, _onMapLoadTimeout);
  }

  void _cancelMapLoadTimeout() {
    _mapLoadTimeoutTimer?.cancel();
    _mapLoadTimeoutTimer = null;
  }

  void _onMapLoadTimeout() {
    if (!mounted || _loadTimedOut) return;
    setState(() {
      _loadTimedOut = true;
      _mapReady = true;
    });
  }

  Widget _buildMapLoader() {
    return ColoredBox(
      color: AppColors.white.withValues(alpha: 0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.inkStrong,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Loading map…',
              style: AppFonts.bodyMedium(color: AppColors.muted).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLoadFailureBanner() {
    return Material(
      color: AppColors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Map tiles blocked. In Google Cloud enable Maps SDK for Android '
          '(and iOS), confirm billing is on, and allow package '
          'com.example.red5 + your debug SHA-1 on the API key. Then fully '
          'restart the app (not hot reload).',
          style: AppFonts.bodySmall(color: AppColors.muted),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _startMapLoadTimeout();
    final connectivity = ref.read(connectivityServiceProvider);
    _isOnline = connectivity.isOnline;
    if (!_isOnline) {
      _mapReady = true;
      _cancelMapLoadTimeout();
    }
    _connectivitySub = connectivity.isOnlineStream.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
        if (!online) {
          _mapReady = true;
          _cancelMapLoadTimeout();
          _markers = {};
          _polylines = {};
          _selectedPinScreen = null;
          _googleMapController = null;
        } else {
          _mapReady = false;
          _loadTimedOut = false;
          _startMapLoadTimeout();
        }
      });
      if (online) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _ensureMarkerIcons();
          await _rebuildMarkersAndPolylines();
        });
      }
    });
    if (widget.routePinId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
    }
    unawaited(() async {
      await _ensureMarkerIcons();
      if (mounted) await _rebuildMarkersAndPolylines();
    }());
  }

  @override
  void didUpdateWidget(covariant OperativeSiteGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selectionOrPinsChanged =
        oldWidget.pins != widget.pins ||
        oldWidget.selectedPinId != widget.selectedPinId ||
        oldWidget.routePinId != widget.routePinId ||
        oldWidget.pinStyle != widget.pinStyle;
    if (selectionOrPinsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (oldWidget.pinStyle != widget.pinStyle) {
          await _ensureMarkerIcons(force: true);
        }
        await _rebuildMarkersAndPolylines();
        await _updateSelectedPinScreen();
      });
    }

    if (oldWidget.pins != widget.pins &&
        widget.pins.isNotEmpty &&
        widget.routePinId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    }
    if (!oldWidget.isLoading && widget.isLoading) {
      _loadTimedOut = false;
      _startMapLoadTimeout();
    }
    if (oldWidget.isLoading && !widget.isLoading && _mapReady) {
      _cancelMapLoadTimeout();
    }
    if (oldWidget.routePinId != widget.routePinId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
    }
  }

  @override
  void dispose() {
    _mapLoadTimeoutTimer?.cancel();
    unawaited(_connectivitySub?.cancel());
    _googleMapController?.dispose();
    super.dispose();
  }

  Future<void> _ensureMarkerIcons({bool force = false}) async {
    if (force) {
      _pinIcon = null;
      _pinSelectedIcon = null;
      _userDotIcon = null;
    }

    // Same site pin art as the dedicated route screen.
    if (widget.pinStyle == OperativeMapPinStyle.circle) {
      _pinIcon ??= await OperativeMapMarkerArt.bitmapCircle(selected: false);
      _pinSelectedIcon ??=
          await OperativeMapMarkerArt.bitmapCircle(selected: true);
    } else {
      _pinIcon ??= await OperativeMapMarkerArt.bitmapTeardrop(selected: false);
      _pinSelectedIcon ??=
          await OperativeMapMarkerArt.bitmapTeardrop(selected: true);
    }
    _userDotIcon ??= await OperativeMapMarkerArt.bitmapUserDot();
  }

  LatLng get _initialCenter => _viewportForPins().center;

  double get _initialZoom => _viewportForPins().zoom;

  ({LatLng center, double zoom}) _viewportForPins() {
    if (widget.pins.isEmpty) {
      return (center: OperativeMapGeocoder.defaultCenter, zoom: 12.5);
    }
    if (widget.pins.length == 1) {
      return (center: widget.pins.first.position, zoom: 14.5);
    }
    final bounds = _boundsFor(widget.pins.map((p) => p.position));
    return (
      center: LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      ),
      zoom: 12,
    );
  }

  LatLngBounds _boundsFor(Iterable<LatLng> points) {
    final list = points.toList(growable: false);
    var south = list.first.latitude;
    var north = list.first.latitude;
    var west = list.first.longitude;
    var east = list.first.longitude;
    for (final point in list.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  Future<void> _rebuildMarkersAndPolylines() async {
    await _ensureMarkerIcons();
    if (!mounted) return;

    final markers = <Marker>{
      for (final pin in widget.pins)
        Marker(
          markerId: MarkerId(pin.id),
          position: pin.position,
          // Teardrop tip / circle bottom sits on the site coordinate.
          anchor: const Offset(0.5, 1),
          icon: pin.id == widget.selectedPinId
              ? (_pinSelectedIcon ?? BitmapDescriptor.defaultMarker)
              : (_pinIcon ?? BitmapDescriptor.defaultMarker),
          infoWindow: InfoWindow(
            title: pin.title,
            snippet: pin.subtitle,
          ),
          onTap: () => widget.onPinTap?.call(pin),
          consumeTapEvents: true,
        ),
    };

    final plan = _routePlan;
    final polylines = <Polyline>{};
    if (plan != null && plan.polyline.length >= 2) {
      final points = plan.polyline
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(growable: false);
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route-outline'),
          points: points,
          width: 7,
          color: const Color(0xFF111827),
        ),
      );
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          width: 4,
          color: const Color(0xFF00A553),
        ),
      );
      markers.add(
        Marker(
          markerId: const MarkerId('route-origin'),
          position: LatLng(plan.origin.latitude, plan.origin.longitude),
          anchor: const Offset(0.5, 0.5),
          icon: _userDotIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  Future<void> _fitCamera() async {
    final controller = _googleMapController;
    if (controller == null || widget.pins.isEmpty) return;
    final padding = widget.embedded ? 48.0 : 72.0;
    try {
      if (widget.pins.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(widget.pins.first.position, 14.5),
        );
        return;
      }
      final bounds = _boundsFor(widget.pins.map((p) => p.position));
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } catch (_) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_initialCenter, _initialZoom),
      );
    }
  }

  Future<void> _fitRouteCamera() async {
    final controller = _googleMapController;
    final plan = _routePlan;
    if (controller == null || plan == null) return;
    final points = <LatLng>[
      LatLng(plan.origin.latitude, plan.origin.longitude),
      for (final p in plan.polyline) LatLng(p.latitude, p.longitude),
      LatLng(plan.destination.latitude, plan.destination.longitude),
    ];
    if (points.isEmpty) return;
    final padding = widget.embedded ? 40.0 : 64.0;
    try {
      final bounds = _boundsFor(points);
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } catch (_) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14),
      );
    }
  }

  Future<void> _recenter() async {
    if (_showRoute) {
      await _fitRouteCamera();
      return;
    }

    final selectedId = widget.selectedPinId;
    OperativeMapPin? target;
    for (final pin in widget.pins) {
      if (pin.id == selectedId) {
        target = pin;
        break;
      }
    }
    target ??= widget.pins.isNotEmpty ? widget.pins.first : null;
    if (target == null) return;
    final controller = _googleMapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(target.position, 15),
    );
  }

  OperativeMapPin? get _selectedPin {
    final selectedId = widget.selectedPinId;
    if (selectedId == null) return null;
    for (final pin in widget.pins) {
      if (pin.id == selectedId) return pin;
    }
    return null;
  }

  bool get _showPinActionCard =>
      widget.routePinId == null &&
      _selectedPin != null &&
      widget.onDrawings != null &&
      widget.onShowRoutes != null;

  bool get _showRoute => widget.routePinId != null;

  OperativeMapPin? _pinById(String? id) {
    if (id == null) return null;
    for (final pin in widget.pins) {
      if (pin.id == id) return pin;
    }
    return null;
  }

  Future<void> _loadRoute() async {
    final routePinId = widget.routePinId;
    if (routePinId == null) {
      if (_routePlan != null || _loadingRoute) {
        setState(() {
          _routePlan = null;
          _loadingRoute = false;
        });
        await _rebuildMarkersAndPolylines();
      }
      return;
    }

    final pin = _pinById(routePinId);
    if (pin == null) return;

    setState(() {
      _loadingRoute = true;
      _routePlan = null;
    });
    await _rebuildMarkersAndPolylines();

    try {
      final service = ref.read(operativeMapRouteServiceProvider);
      final plan = await service.buildRoute(
        destination: ll.LatLng(
          pin.position.latitude,
          pin.position.longitude,
        ),
        destinationTitle: pin.title,
        destinationSubtitle: pin.subtitle,
      );
      if (!mounted || widget.routePinId != routePinId) return;
      setState(() {
        _routePlan = plan;
        _loadingRoute = false;
      });
      await _rebuildMarkersAndPolylines();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteCamera());
    } catch (_) {
      if (!mounted || widget.routePinId != routePinId) return;
      setState(() => _loadingRoute = false);
    }
  }

  void _exitRoute() {
    widget.onExitRoute?.call();
    setState(() {
      _routePlan = null;
      _loadingRoute = false;
    });
    unawaited(_rebuildMarkersAndPolylines());
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  Future<void> _updateSelectedPinScreen() async {
    final controller = _googleMapController;
    final pin = _selectedPin;
    if (controller == null || !_mapReady || pin == null || !_useNetworkTiles) {
      if (_selectedPinScreen != null && mounted) {
        setState(() => _selectedPinScreen = null);
      }
      return;
    }
    try {
      final screen = await controller.getScreenCoordinate(pin.position);
      final yOffset = widget.pinStyle == OperativeMapPinStyle.circle
          ? 22.0
          : 56.0;
      if (!mounted) return;
      setState(() {
        _selectedPinScreen = Offset(
          screen.x.toDouble(),
          screen.y.toDouble() - yOffset,
        );
        _cameraTick++;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedPinScreen = null;
        _cameraTick++;
      });
    }
  }

  Offset? _pinCardAnchor(Size mapSize) {
    final pin = _selectedPin;
    if (pin == null) return null;

    if (_useNetworkTiles) {
      return _selectedPinScreen ??
          Offset(mapSize.width / 2, mapSize.height * 0.28);
    }

    return OperativePaintedSiteMap.pinOverlayAnchor(
      pin: pin,
      pins: widget.pins,
      mapSize: mapSize,
      pinStyle: widget.pinStyle,
    );
  }

  Widget _buildPinActionCard(Size mapSize) {
    if (!_showPinActionCard) return const SizedBox.shrink();

    final anchor = _pinCardAnchor(mapSize);
    if (anchor == null) return const SizedBox.shrink();

    const cardWidth = 148.0;
    const cardHeight = 96.0;
    const gap = 8.0;

    final left = (anchor.dx - cardWidth / 2).clamp(
      8.0,
      mapSize.width - cardWidth - 8,
    );
    final top = (anchor.dy - cardHeight - gap).clamp(
      8.0,
      mapSize.height - cardHeight - 8,
    );

    return Positioned(
      left: left,
      top: top,
      child: OperativeMapPinActionCard(
        onDrawings: widget.onDrawings!,
        onShowRoutes: widget.onShowRoutes!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = _cameraTick;

    final mapBody = LayoutBuilder(
      builder: (context, constraints) {
        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_usePaintedFallback)
              OperativePaintedSiteMap(
                pins: widget.pins,
                selectedPinId: widget.selectedPinId,
                onPinTap: widget.onPinTap,
                onMapBackgroundTap: _showRoute
                    ? null
                    : widget.onClearSelection,
                isDark: widget.isDark,
                pinStyle: widget.pinStyle,
              )
            else
              _buildNetworkMap(),
            if (_usePaintedFallback && _routePlan != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _OperativeOfflineRoutePainter(
                      pins: widget.pins,
                      route: _routePlan!,
                    ),
                  ),
                ),
              ),
            if (_usePaintedFallback && _routePlan != null)
              _buildOfflineUserDot(mapSize),
            if (_showMapLoader) Positioned.fill(child: _buildMapLoader()),
            if (_loadTimedOut && _useNetworkTiles)
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: _buildMapLoadFailureBanner(),
              ),
            if (!_showMapLoader) _buildPinActionCard(mapSize),
            if (_showRoute)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: OperativeRouteBottomCard(
                  route: _routePlan,
                  isLoading: _loadingRoute,
                  onClose: _exitRoute,
                  onOpenExternalNavigation: widget.onOpenExternalNavigation,
                ),
              ),
            if (widget.showFloatingControls)
              Positioned(
                right: 12,
                bottom: _showRoute
                    ? (widget.onOpenExternalNavigation != null ? 170 : 108)
                    : 16,
                child: ProjectMapFloatingButtons(
                  onCurrentLocation: _useNetworkTiles
                      ? () => unawaited(_recenter())
                      : () {},
                  onToggleTheme: widget.onToggleTheme ?? () {},
                ),
              ),
            if (_usePaintedFallback)
              Positioned(
                left: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.inkStrong.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'Offline map',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );

    Widget result = mapBody;

    // Do not ClipRRect the native GoogleMap — it can blank the Android surface.
    if (widget.embedded) {
      result = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: mapBody,
      );
      result = NotificationListener<ScrollNotification>(
        onNotification: (_) => true,
        child: result,
      );
    }

    return result;
  }

  Widget _buildNetworkMap() {
    return GoogleMap(
      key: ValueKey(
        'gmap-${widget.isDark}-${widget.pins.length}-${widget.routePinId ?? "none"}',
      ),
      initialCameraPosition: CameraPosition(
        target: _initialCenter,
        zoom: _initialZoom,
      ),
      // Default Google style — custom ride styles previously looked blank/beige.
      mapType: MapType.normal,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      liteModeEnabled: false,
      onMapCreated: (controller) async {
        _googleMapController = controller;
        await _ensureMarkerIcons();
        await _rebuildMarkersAndPolylines();
        if (!mounted) return;
        setState(() => _mapReady = true);
        _cancelMapLoadTimeout();
        if (_showRoute && _routePlan != null) {
          await _fitRouteCamera();
        } else {
          await _fitCamera();
        }
        await _updateSelectedPinScreen();
      },
      onCameraMove: (_) {
        if (_showPinActionCard && mounted) {
          setState(() => _cameraTick++);
        }
      },
      onCameraIdle: () {
        unawaited(_updateSelectedPinScreen());
      },
      onTap: (_) {
        if (_showRoute) return;
        widget.onClearSelection?.call();
      },
    );
  }

  Widget _buildOfflineUserDot(Size mapSize) {
    final route = _routePlan;
    if (route == null) return const SizedBox.shrink();

    final bounds = _routeBounds(widget.pins, route);
    final normalized = _latLngToNormalized(route.origin, bounds);
    const size = 26.0;
    return Positioned(
      left: normalized.dx * mapSize.width - size / 2,
      top: normalized.dy * mapSize.height - size / 2,
      child: IgnorePointer(child: OperativeMapMarkerArt.userLocationDot()),
    );
  }

  static OperativePaintedMapBounds _routeBounds(
    List<OperativeMapPin> pins,
    OperativeRoutePlan route,
  ) {
    final base = OperativePaintedSiteMap.boundsFor(pins);
    var south = base.south;
    var north = base.north;
    var west = base.west;
    var east = base.east;

    for (final point in route.polyline) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    const pad = 0.008;
    return OperativePaintedMapBounds(
      south: south - pad,
      north: north + pad,
      west: west - pad,
      east: east + pad,
    );
  }

  static Offset _latLngToNormalized(
    ll.LatLng point,
    OperativePaintedMapBounds bounds,
  ) {
    final latSpan = bounds.north - bounds.south;
    final lngSpan = bounds.east - bounds.west;
    final x = lngSpan <= 0 ? 0.5 : (point.longitude - bounds.west) / lngSpan;
    final y = latSpan <= 0
        ? 0.5
        : 1 - (point.latitude - bounds.south) / latSpan;
    return Offset(x.clamp(0.05, 0.95), y.clamp(0.2, 0.8));
  }
}

class _OperativeOfflineRoutePainter extends CustomPainter {
  _OperativeOfflineRoutePainter({required this.pins, required this.route});

  final List<OperativeMapPin> pins;
  final OperativeRoutePlan route;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.polyline.length < 2) return;

    final bounds = _OperativeSiteGoogleMapState._routeBounds(pins, route);
    final points = <Offset>[
      for (final point in route.polyline)
        () {
          final normalized = _OperativeSiteGoogleMapState._latLngToNormalized(
            point,
            bounds,
          );
          return Offset(
            normalized.dx * size.width,
            normalized.dy * size.height,
          );
        }(),
    ];

    final borderPaint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final routePaint = Paint()
      ..color = const Color(0xFF00A553)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant _OperativeOfflineRoutePainter oldDelegate) {
    return oldDelegate.route != route || oldDelegate.pins != pins;
  }
}

/// Builds map pins from project summaries (geocodes addresses once).
Future<List<OperativeMapPin>> resolveProjectMapPins({
  required List<EmployeeProjectSummary> projects,
  required OperativeMapGeocoder geocoder,
}) async {
  if (projects.isEmpty) return const [];

  return Future.wait(
    projects.asMap().entries.map((entry) async {
      final i = entry.key;
      final project = entry.value;
      final position = await geocoder.resolve(
        address: project.address,
        stableId: project.id,
        index: i,
      );
      return OperativeMapPin(
        id: 'project-${project.id}',
        title: project.title,
        subtitle: project.address,
        position: position,
      );
    }),
  );
}

List<OperativeMapPin> pinsFromProjectMapJobs(List<ProjectMapJob> jobs) {
  return jobs
      .map(
        (job) => OperativeMapPin(
          id: 'job-${job.id}',
          title: job.title,
          subtitle: job.address,
          position: job.position,
        ),
      )
      .toList(growable: false);
}

Future<List<OperativeMapPin>> resolveEmployeeJobMapPins({
  required List<EmployeeJobSummary> jobs,
  required OperativeMapGeocoder geocoder,
}) async {
  if (jobs.isEmpty) return const [];

  return Future.wait(
    jobs.asMap().entries.map((entry) async {
      final i = entry.key;
      final job = entry.value;
      final position = await geocoder.resolve(
        address: job.location,
        stableId: job.id,
        index: i,
      );
      return OperativeMapPin(
        id: 'job-${job.id}',
        title: job.title,
        subtitle: job.location,
        position: position,
      );
    }),
  );
}

Future<List<OperativeMapPin>> resolveJobMapPins({
  required List<ProjectMapJob> jobs,
  required OperativeMapGeocoder geocoder,
}) async {
  if (jobs.isEmpty) return const [];

  return Future.wait(
    jobs.asMap().entries.map((entry) async {
      final i = entry.key;
      final job = entry.value;
      final hasCoords =
          job.position.latitude != 0 || job.position.longitude != 0;
      final position = hasCoords
          ? job.position
          : await geocoder.resolve(
              address: job.address,
              stableId: job.id,
              index: i,
            );
      return OperativeMapPin(
        id: 'job-${job.id}',
        title: job.title,
        subtitle: job.address,
        position: position,
      );
    }),
  );
}

/// Async loader for project detail map (jobs / sites).
class OperativeJobsMapLoader extends ConsumerStatefulWidget {
  const OperativeJobsMapLoader({
    super.key,
    required this.jobs,
    required this.selectedJobId,
    required this.onJobSelected,
    required this.isDark,
    required this.onToggleTheme,
    this.onDrawings,
    this.onShowRoutes,
    this.onClearSelection,
    this.routePinId,
    this.onExitRoute,
    this.onOpenExternalNavigation,
    this.borderRadius = 0,
    this.embedded = false,
    this.pinStyle = OperativeMapPinStyle.teardrop,
  });

  final List<ProjectMapJob> jobs;
  final int? selectedJobId;
  final ValueChanged<int> onJobSelected;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback? onDrawings;
  final VoidCallback? onShowRoutes;
  final VoidCallback? onClearSelection;
  final String? routePinId;
  final VoidCallback? onExitRoute;
  final VoidCallback? onOpenExternalNavigation;
  final double borderRadius;
  final bool embedded;
  final OperativeMapPinStyle pinStyle;

  @override
  ConsumerState<OperativeJobsMapLoader> createState() =>
      _OperativeJobsMapLoaderState();
}

class _OperativeJobsMapLoaderState
    extends ConsumerState<OperativeJobsMapLoader> {
  List<OperativeMapPin> _pins = const [];
  var _loadingPins = false;

  @override
  void initState() {
    super.initState();
    final cached = ref
        .read(operativeMapPinsCacheProvider)
        .cachedJobPins(widget.jobs);
    if (cached != null) {
      _pins = cached;
    }
    _resolvePins();
  }

  @override
  void didUpdateWidget(covariant OperativeJobsMapLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.jobs, widget.jobs)) {
      _resolvePins();
    }
  }

  Future<void> _resolvePins() async {
    final pinCache = ref.read(operativeMapPinsCacheProvider);
    final cached = pinCache.cachedJobPins(widget.jobs);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _pins = cached;
        _loadingPins = false;
      });
      return;
    }

    if (_pins.isEmpty && mounted) {
      setState(() => _loadingPins = true);
    }

    final geocoder = ref.read(operativeMapGeocoderProvider);
    final pins = await resolveJobMapPins(jobs: widget.jobs, geocoder: geocoder);
    pinCache.storeJobPins(widget.jobs, pins);
    if (!mounted) return;
    setState(() {
      _pins = pins;
      _loadingPins = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OperativeSiteGoogleMap(
      pins: _pins,
      selectedPinId: widget.selectedJobId == null
          ? null
          : 'job-${widget.selectedJobId}',
      onPinTap: (pin) {
        final id = int.tryParse(pin.id.replaceFirst('job-', ''));
        if (id != null) widget.onJobSelected(id);
      },
      onDrawings: widget.onDrawings,
      onShowRoutes: widget.onShowRoutes,
      onClearSelection: widget.onClearSelection,
      routePinId: widget.routePinId,
      onExitRoute: widget.onExitRoute,
      onOpenExternalNavigation: widget.onOpenExternalNavigation,
      borderRadius: widget.borderRadius,
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      isLoading: _loadingPins,
      embedded: widget.embedded,
      pinStyle: widget.pinStyle,
    );
  }
}

/// Async loader wrapper for project tab map.
class OperativeProjectsMapLoader extends ConsumerStatefulWidget {
  const OperativeProjectsMapLoader({
    super.key,
    required this.projects,
    required this.selectedProjectId,
    required this.onProjectSelected,
    required this.onDrawings,
    required this.onShowRoutes,
    this.onClearSelection,
    this.routePinId,
    this.onExitRoute,
    this.onOpenExternalNavigation,
    required this.isDark,
    required this.onToggleTheme,
    this.borderRadius = 16,
    this.embedded = true,
  });

  final List<EmployeeProjectSummary> projects;
  final int? selectedProjectId;
  final ValueChanged<int> onProjectSelected;
  final VoidCallback onDrawings;
  final VoidCallback onShowRoutes;
  final VoidCallback? onClearSelection;
  final String? routePinId;
  final VoidCallback? onExitRoute;
  final VoidCallback? onOpenExternalNavigation;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final double borderRadius;
  final bool embedded;

  @override
  ConsumerState<OperativeProjectsMapLoader> createState() =>
      _OperativeProjectsMapLoaderState();
}

class _OperativeProjectsMapLoaderState
    extends ConsumerState<OperativeProjectsMapLoader> {
  List<OperativeMapPin> _pins = const [];
  var _loadingPins = false;

  @override
  void initState() {
    super.initState();
    final cached = ref
        .read(operativeMapPinsCacheProvider)
        .cachedProjectPins(widget.projects);
    if (cached != null) {
      _pins = cached;
    }
    _resolvePins();
  }

  @override
  void didUpdateWidget(covariant OperativeProjectsMapLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.projects, widget.projects)) {
      _resolvePins();
    }
  }

  Future<void> _resolvePins() async {
    final pinCache = ref.read(operativeMapPinsCacheProvider);
    final cached = pinCache.cachedProjectPins(widget.projects);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _pins = cached;
        _loadingPins = false;
      });
      return;
    }

    if (_pins.isEmpty && mounted) {
      setState(() => _loadingPins = true);
    }

    final geocoder = ref.read(operativeMapGeocoderProvider);
    final pins = await resolveProjectMapPins(
      projects: widget.projects,
      geocoder: geocoder,
    );
    pinCache.storeProjectPins(widget.projects, pins);
    if (!mounted) return;
    setState(() {
      _pins = pins;
      _loadingPins = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OperativeSiteGoogleMap(
      pins: _pins,
      selectedPinId: widget.selectedProjectId == null
          ? null
          : 'project-${widget.selectedProjectId}',
      onPinTap: (pin) {
        final id = int.tryParse(pin.id.replaceFirst('project-', ''));
        if (id != null) widget.onProjectSelected(id);
      },
      onDrawings: widget.onDrawings,
      onShowRoutes: widget.onShowRoutes,
      onClearSelection: widget.onClearSelection,
      routePinId: widget.routePinId,
      onExitRoute: widget.onExitRoute,
      onOpenExternalNavigation: widget.onOpenExternalNavigation,
      borderRadius: widget.borderRadius,
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      isLoading: _loadingPins,
      embedded: widget.embedded,
      pinStyle: OperativeMapPinStyle.teardrop,
    );
  }
}

/// Async loader for operative home job map (assigned jobs).
class OperativeEmployeeJobsMapLoader extends ConsumerStatefulWidget {
  const OperativeEmployeeJobsMapLoader({
    super.key,
    required this.jobs,
    required this.selectedJobId,
    required this.onJobSelected,
    required this.onDrawings,
    required this.onShowRoutes,
    this.onClearSelection,
    this.routePinId,
    this.onExitRoute,
    this.onOpenExternalNavigation,
    required this.isDark,
    required this.onToggleTheme,
    this.borderRadius = 16,
    this.embedded = true,
  });

  final List<EmployeeJobSummary> jobs;
  final int? selectedJobId;
  final ValueChanged<int> onJobSelected;
  final VoidCallback onDrawings;
  final VoidCallback onShowRoutes;
  final VoidCallback? onClearSelection;
  final String? routePinId;
  final VoidCallback? onExitRoute;
  final VoidCallback? onOpenExternalNavigation;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final double borderRadius;
  final bool embedded;

  @override
  ConsumerState<OperativeEmployeeJobsMapLoader> createState() =>
      _OperativeEmployeeJobsMapLoaderState();
}

class _OperativeEmployeeJobsMapLoaderState
    extends ConsumerState<OperativeEmployeeJobsMapLoader> {
  List<OperativeMapPin> _pins = const [];
  var _loadingPins = false;

  @override
  void initState() {
    super.initState();
    final cached = ref
        .read(operativeMapPinsCacheProvider)
        .cachedEmployeeJobPins(widget.jobs);
    if (cached != null) {
      _pins = cached;
    }
    _resolvePins();
  }

  @override
  void didUpdateWidget(covariant OperativeEmployeeJobsMapLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.jobs, widget.jobs)) {
      _resolvePins();
    }
  }

  Future<void> _resolvePins() async {
    final pinCache = ref.read(operativeMapPinsCacheProvider);
    final cached = pinCache.cachedEmployeeJobPins(widget.jobs);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _pins = cached;
        _loadingPins = false;
      });
      return;
    }

    if (_pins.isEmpty && mounted) {
      setState(() => _loadingPins = true);
    }

    final geocoder = ref.read(operativeMapGeocoderProvider);
    final pins = await resolveEmployeeJobMapPins(
      jobs: widget.jobs,
      geocoder: geocoder,
    );
    pinCache.storeEmployeeJobPins(widget.jobs, pins);
    if (!mounted) return;
    setState(() {
      _pins = pins;
      _loadingPins = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OperativeSiteGoogleMap(
      pins: _pins,
      selectedPinId: widget.selectedJobId == null
          ? null
          : 'job-${widget.selectedJobId}',
      onPinTap: (pin) {
        final id = int.tryParse(pin.id.replaceFirst('job-', ''));
        if (id != null) widget.onJobSelected(id);
      },
      onDrawings: widget.onDrawings,
      onShowRoutes: widget.onShowRoutes,
      onClearSelection: widget.onClearSelection,
      routePinId: widget.routePinId,
      onExitRoute: widget.onExitRoute,
      onOpenExternalNavigation: widget.onOpenExternalNavigation,
      borderRadius: widget.borderRadius,
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      isLoading: _loadingPins,
      embedded: widget.embedded,
      pinStyle: OperativeMapPinStyle.teardrop,
    );
  }
}
