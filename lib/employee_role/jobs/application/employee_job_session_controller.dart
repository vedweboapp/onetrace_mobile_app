import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

final employeeJobSessionProvider =
    StateNotifierProvider<EmployeeJobSessionController, EmployeeJobSessionState>(
  (ref) => EmployeeJobSessionController(ref.read(localStorageProvider)),
);

final class EmployeeJobSessionState {
  const EmployeeJobSessionState({
    this.activeJobStarts = const {},
    this.tick = 0,
  });

  final Map<int, DateTime> activeJobStarts;
  final int tick;

  Duration elapsedFor(int jobId) {
    final start = activeJobStarts[jobId];
    if (start == null) return Duration.zero;
    return DateTime.now().difference(start) + Duration(milliseconds: tick % 1);
  }

  EmployeeJobSessionState copyWith({
    Map<int, DateTime>? activeJobStarts,
    int? tick,
  }) {
    return EmployeeJobSessionState(
      activeJobStarts: activeJobStarts ?? this.activeJobStarts,
      tick: tick ?? this.tick,
    );
  }
}

final class EmployeeJobSessionController
    extends StateNotifier<EmployeeJobSessionState> {
  EmployeeJobSessionController(this._storage) : super(const EmployeeJobSessionState());

  final LocalStorage _storage;

  static String _dailyKey(int jobId) {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$jobId:${now.year}-$month-$day';
  }

  Map<String, dynamic> _readVerifiedMap() {
    final raw = _storage.getString(LocalStorageKeys.employeeJobSafetyVerified);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return Map<String, dynamic>.from(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _persistVerified(int jobId) async {
    final map = _readVerifiedMap()..[_dailyKey(jobId)] = true;
    await _storage.setString(
      LocalStorageKeys.employeeJobSafetyVerified,
      jsonEncode(map),
    );
  }

  bool isJobStarted(int jobId) {
    if (state.activeJobStarts.containsKey(jobId)) return true;
    return _readVerifiedMap()[_dailyKey(jobId)] == true;
  }

  bool needsSafetyVerification({
    required int jobId,
    EmployeeJobStatus? status,
  }) {
    if (status == EmployeeJobStatus.completed) return false;
    return !isJobStarted(jobId);
  }

  void startJob(int jobId) {
    if (!state.activeJobStarts.containsKey(jobId)) {
      final updated = Map<int, DateTime>.from(state.activeJobStarts)
        ..[jobId] = DateTime.now();
      state = state.copyWith(activeJobStarts: updated);
      _ensureTicker();
    }
    unawaited(_persistVerified(jobId));
  }

  void _ensureTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.activeJobStarts.isEmpty) {
        _ticker?.cancel();
        _ticker = null;
        return;
      }
      state = state.copyWith(tick: state.tick + 1);
    });
  }

  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
