import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/widgets/connectivity_status_banner.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/offline/operative_sync_coordinator.dart';

/// Wraps the app shell and shows global offline / back-online UI.
final class ConnectivityUiScope extends ConsumerStatefulWidget {
  const ConnectivityUiScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectivityUiScope> createState() =>
      _ConnectivityUiScopeState();
}

final class _ConnectivityUiScopeState extends ConsumerState<ConnectivityUiScope>
    with SingleTickerProviderStateMixin {
  StreamSubscription<bool>? _subscription;
  late bool _isOnline;
  late final AnimationController _bannerController;
  late final Animation<Offset> _bannerSlide;
  late final Animation<double> _bannerFade;

  @override
  void initState() {
    super.initState();
    final connectivity = ref.read(connectivityServiceProvider);
    _isOnline = connectivity.isOnline;

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _bannerController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _bannerFade = CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    if (!_isOnline) {
      _bannerController.value = 1;
    }

    _subscription = connectivity.isOnlineStream.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    final wasOnline = _isOnline;
    if (wasOnline == online) return;

    setState(() => _isOnline = online);

    if (online) {
      unawaited(_bannerController.reverse());
      tryShowAppTopToast(
        title: AppStrings.connectivityOnlineTitle,
        subtitle: AppStrings.connectivityOnlineSubtitle,
        type: AppTopToastType.success,
        duration: const Duration(seconds: 3),
      );
    } else {
      unawaited(_bannerController.forward(from: 0));
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(operativeSyncBootstrapProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_isOnline)
          Positioned(
            left: 16,
            right: 16,
            top: topInset + 10,
            child: SlideTransition(
              position: _bannerSlide,
              child: FadeTransition(
                opacity: _bannerFade,
                child: const ConnectivityOfflineBanner(),
              ),
            ),
          ),
      ],
    );
  }
}
