import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/widgets/top_snackbar.dart';

/// Shows a top toast when a load takes too long on a live (possibly weak) network.
///
/// Use via [begin] for UI loaders / downloads, or through
/// [SlowNetworkToastInterceptor] for Dio API calls.
final class SlowNetworkToast {
  SlowNetworkToast._();

  /// RequestOptions.extra key — set to `true` to skip watching that call.
  static const String skipExtraKey = 'skipSlowNetworkToast';

  /// How long a request may run before we warn about a slow/weak connection.
  static const Duration warnAfter = Duration(milliseconds: 2800);

  /// Minimum gap between consecutive weak-network toasts.
  static const Duration toastCooldown = Duration(seconds: 12);

  static DateTime? _lastToastAt;
  static int _activeWatches = 0;
  static int _suppressCount = 0;
  static Timer? _sharedTimer;

  /// Whether weak-network toasts are currently suppressed (e.g. form upload).
  static bool get isSuppressed => _suppressCount > 0;

  /// Runs [action] without showing the slow-network toast.
  ///
  /// Prefer this while a dedicated loader (e.g. "Submitting forms…") is visible.
  static Future<T> suppressWhile<T>(Future<T> Function() action) async {
    _suppressCount += 1;
    try {
      return await action();
    } finally {
      if (_suppressCount > 0) _suppressCount -= 1;
    }
  }

  /// Starts watching a load. Call [cancel] (or the returned disposer) when done.
  ///
  /// If the load is still running after [warnAfter] and the device is online,
  /// a top warning toast is shown (rate-limited).
  static void Function() begin({
    Duration? after,
    String? title,
    String? subtitle,
  }) {
    if (isSuppressed) {
      return () {};
    }

    _activeWatches += 1;
    _ensureSharedTimer(
      after: after ?? warnAfter,
      title: title,
      subtitle: subtitle,
    );

    var cancelled = false;
    return () {
      if (cancelled) return;
      cancelled = true;
      end();
    };
  }

  /// Ends one active watch started by [begin].
  static void end() {
    if (_activeWatches <= 0) return;
    _activeWatches -= 1;
    if (_activeWatches == 0) {
      _sharedTimer?.cancel();
      _sharedTimer = null;
    }
  }

  /// Convenience wrapper for any async load.
  static Future<T> run<T>(
    Future<T> Function() action, {
    Duration? after,
    String? title,
    String? subtitle,
  }) async {
    final cancel = begin(after: after, title: title, subtitle: subtitle);
    try {
      return await action();
    } finally {
      cancel();
    }
  }

  static void _ensureSharedTimer({
    required Duration after,
    String? title,
    String? subtitle,
  }) {
    if (_sharedTimer?.isActive == true) return;
    _sharedTimer = Timer(after, () {
      _sharedTimer = null;
      if (_activeWatches <= 0) return;
      maybeShowWeakNetworkToast(title: title, subtitle: subtitle);
    });
  }

  /// Shows the weak/slow network toast if online and cooldown allows.
  static void maybeShowWeakNetworkToast({
    String? title,
    String? subtitle,
  }) {
    if (isSuppressed) return;

    final connectivity = _tryConnectivity();
    if (connectivity == null || !connectivity.isOnline) return;

    final now = DateTime.now();
    final last = _lastToastAt;
    if (last != null && now.difference(last) < toastCooldown) return;
    _lastToastAt = now;

    final onCellular = connectivity.isCellular;
    final resolvedTitle =
        (title ?? AppStrings.connectivityWeakTitle).trim();
    final resolvedSubtitle = (subtitle ??
            (onCellular
                ? AppStrings.connectivityWeakCellularSubtitle
                : AppStrings.connectivityWeakSubtitle))
        .trim();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      tryShowAppTopToast(
        title: resolvedTitle,
        subtitle: resolvedSubtitle,
        type: AppTopToastType.warning,
        duration: const Duration(seconds: 4),
      );
    });
  }

  static ConnectivityService? _tryConnectivity() {
    try {
      if (!sl.isRegistered<ConnectivityService>()) return null;
      return sl<ConnectivityService>();
    } catch (_) {
      return null;
    }
  }
}
