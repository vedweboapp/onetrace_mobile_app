import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return sl<ConnectivityService>();
});

/// Debounced online/offline signal for technician form sync.
final class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    unawaited(_emitInitialState());
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  final _controller = StreamController<bool>.broadcast();
  bool _lastOnline = true;
  Timer? _debounceTimer;

  Stream<bool> get isOnlineStream => _controller.stream;

  bool get isOnline => _lastOnline;

  Future<void> _emitInitialState() async {
    final results = await _connectivity.checkConnectivity();
    _emitOnline(_resultsIndicateOnline(results));
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _emitOnline(_resultsIndicateOnline(results));
    });
  }

  static bool _resultsIndicateOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _emitOnline(bool online) {
    if (_lastOnline == online) return;
    _lastOnline = online;
    _controller.add(online);
  }

  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_controller.close());
  }
}
