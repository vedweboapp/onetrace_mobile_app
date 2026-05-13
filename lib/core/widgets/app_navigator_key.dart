import 'package:flutter/material.dart';

/// Root [NavigatorState] for [GoRouter]. Used to show overlay toasts when no
/// [BuildContext] is available (e.g. Dio interceptors).
final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();
