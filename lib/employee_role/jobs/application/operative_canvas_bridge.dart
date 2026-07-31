import 'package:flutter/material.dart';

typedef OperativePinTapHandler =
    Future<void> Function(BuildContext hostContext, int pinId);
typedef OperativePinCompleteChecker = bool Function(int pinId);

/// Registers callbacks while an operative workflow canvas is open (GoRouter
/// cannot pass closures through route `extra`).
class OperativeCanvasBridge {
  OperativeCanvasBridge._();

  static final _pinTapHandlers = <int, OperativePinTapHandler>{};
  static final _completionCheckers = <int, OperativePinCompleteChecker>{};
  static final _completionNotifiers = <int, ValueNotifier<int>>{};

  static void register({
    required int jobId,
    required OperativePinTapHandler onPinTap,
    required OperativePinCompleteChecker isPinComplete,
  }) {
    _pinTapHandlers[jobId] = onPinTap;
    _completionCheckers[jobId] = isPinComplete;
    _completionNotifiers.putIfAbsent(jobId, () => ValueNotifier<int>(0));
  }

  static void unregister(int jobId) {
    _pinTapHandlers.remove(jobId);
    _completionCheckers.remove(jobId);
    _completionNotifiers.remove(jobId)?.dispose();
  }

  static ValueNotifier<int>? completionNotifier(int jobId) =>
      _completionNotifiers[jobId];

  static Future<void>? onPinTap(
    BuildContext hostContext,
    int? jobId,
    int pinId,
  ) {
    if (jobId == null) return null;
    return _pinTapHandlers[jobId]?.call(hostContext, pinId);
  }

  static bool isPinComplete(int? jobId, int pinId) {
    if (jobId == null) return false;
    final checker = _completionCheckers[jobId];
    if (checker == null) return false;
    try {
      return checker(pinId);
    } catch (_) {
      // Checker may briefly run while the registering route is deactivated.
      return false;
    }
  }

  static void notifyCompletionChanged(int jobId) {
    final notifier = _completionNotifiers[jobId];
    if (notifier != null) {
      notifier.value++;
    }
  }
}
