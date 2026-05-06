import 'package:flutter/material.dart';

/// Shared [NavigatorObserver] so screens (e.g. dashboard) can use [RouteAware]
/// and refresh when a route on top is popped.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
