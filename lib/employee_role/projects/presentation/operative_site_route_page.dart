import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/projects/data/operative_map_geocoder.dart';
import 'package:red5/employee_role/projects/data/operative_map_pin.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_map_external_navigation.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_painted_site_map.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_site_google_map.dart';

/// Full-screen Uber/Rapido-style route from operative GPS to a site pin.
class OperativeSiteRoutePage extends ConsumerStatefulWidget {
  const OperativeSiteRoutePage({
    super.key,
    required this.title,
    this.subtitle,
    this.stableId = 0,
    this.latitude,
    this.longitude,
  });

  static const path = '/employee-role/site-route';
  static const name = 'operative-site-route';

  final String title;
  final String? subtitle;
  final int stableId;
  final double? latitude;
  final double? longitude;

  static OperativeSiteRoutePage? fromExtra(Object? extra) {
    if (extra is! Map) return null;
    final map = Map<String, dynamic>.from(extra);

    final rawTitle = map['title'];
    final title = rawTitle is String && rawTitle.trim().isNotEmpty
        ? rawTitle.trim()
        : 'Site location';

    final rawSubtitle = map['subtitle'];
    final subtitle = rawSubtitle is String && rawSubtitle.trim().isNotEmpty
        ? rawSubtitle.trim()
        : null;

    final rawStableId = map['stableId'];
    final stableId = rawStableId is int
        ? rawStableId
        : int.tryParse(rawStableId?.toString() ?? '') ?? 0;

    double? latitude;
    double? longitude;
    final rawLat = map['latitude'];
    final rawLng = map['longitude'];
    if (rawLat is num) latitude = rawLat.toDouble();
    if (rawLng is num) longitude = rawLng.toDouble();

    return OperativeSiteRoutePage(
      title: title,
      subtitle: subtitle,
      stableId: stableId,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Push the dedicated route screen (operative → site).
  static Future<void> open(
    BuildContext context, {
    required String title,
    String? subtitle,
    int stableId = 0,
    double? latitude,
    double? longitude,
  }) {
    return context.push(
      path,
      extra: <String, Object?>{
        'title': title,
        'subtitle': subtitle,
        'stableId': stableId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }

  @override
  ConsumerState<OperativeSiteRoutePage> createState() =>
      _OperativeSiteRoutePageState();
}

class _OperativeSiteRoutePageState extends ConsumerState<OperativeSiteRoutePage> {
  OperativeMapPin? _destinationPin;
  var _resolvingPin = true;
  String? _resolveError;
  var _isDarkMap = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_resolveDestination);
  }

  Future<void> _resolveDestination() async {
    setState(() {
      _resolvingPin = true;
      _resolveError = null;
      _destinationPin = null;
    });

    try {
      LatLng position;
      final lat = widget.latitude;
      final lng = widget.longitude;
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        position = LatLng(lat, lng);
      } else {
        final geocoder = ref.read(operativeMapGeocoderProvider);
        position = await geocoder.resolve(
          address: widget.subtitle ?? widget.title,
          stableId: widget.stableId,
        );
      }

      if (!mounted) return;
      setState(() {
        _destinationPin = OperativeMapPin(
          id: 'route-${widget.stableId}',
          title: widget.title,
          subtitle: widget.subtitle,
          position: position,
        );
        _resolvingPin = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolveError = 'Could not locate this site on the map.';
        _resolvingPin = false;
      });
    }
  }

  Future<void> _openExternalNavigation() async {
    final pin = _destinationPin;
    if (pin == null) return;
    await openOperativeMapExternalNavigation(
      context,
      latitude: pin.position.latitude,
      longitude: pin.position.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pin = _destinationPin;
    final subtitle = widget.subtitle?.trim();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: AppColors.transparent,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route to site',
              style: AppFonts.titleMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: _resolvingPin
          ? const _RoutePageLoader()
          : _resolveError != null
              ? _RouteErrorState(
                  message: _resolveError!,
                  onRetry: _resolveDestination,
                )
              : pin == null
                  ? const SizedBox.shrink()
                  : OperativeSiteGoogleMap(
                      pins: [pin],
                      routePinId: pin.id,
                      onExitRoute: () {
                        if (context.canPop()) context.pop();
                      },
                      borderRadius: 0,
                      isDark: _isDarkMap,
                      onToggleTheme: () =>
                          setState(() => _isDarkMap = !_isDarkMap),
                      embedded: false,
                      showFloatingControls: true,
                      pinStyle: OperativeMapPinStyle.teardrop,
                      onOpenExternalNavigation: _openExternalNavigation,
                    ),
    );
  }
}

class _RoutePageLoader extends StatelessWidget {
  const _RoutePageLoader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
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
              'Finding route to site…',
              style: AppFonts.bodyMedium(color: AppColors.muted).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteErrorState extends StatelessWidget {
  const _RouteErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 40,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
