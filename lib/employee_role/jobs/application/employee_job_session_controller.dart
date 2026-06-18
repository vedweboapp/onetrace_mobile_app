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
    return DateTime.now().difference(start);
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
  EmployeeJobSessionController(this._storage)
      : super(const EmployeeJobSessionState()) {
    _restoreFromStorage();
  }

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

  Map<String, int> _readStartTimes() {
    final raw = _storage.getString(LocalStorageKeys.employeeJobTimerStarts);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, int>{};
      decoded.forEach((key, value) {
        final jobId = key.toString();
        final millis = switch (value) {
          int v => v,
          num v => v.toInt(),
          String v => int.tryParse(v),
          _ => null,
        };
        if (millis != null) out[jobId] = millis;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Set<int> _readCompletedJobIds() {
    final raw = _storage.getString(LocalStorageKeys.employeeJobTimerCompleted);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <int>{};
      decoded.forEach((key, value) {
        if (value == true) {
          final jobId = int.tryParse(key.toString());
          if (jobId != null) out.add(jobId);
        }
      });
      return out;
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

  Future<void> _persistStartTimes() async {
    final map = <String, int>{
      for (final entry in state.activeJobStarts.entries)
        entry.key.toString(): entry.value.millisecondsSinceEpoch,
    };
    await _storage.setString(
      LocalStorageKeys.employeeJobTimerStarts,
      jsonEncode(map),
    );
  }

  Future<void> _persistCompleted(Set<int> completed) async {
    final map = <String, bool>{
      for (final jobId in completed) jobId.toString(): true,
    };
    await _storage.setString(
      LocalStorageKeys.employeeJobTimerCompleted,
      jsonEncode(map),
    );
  }

  void _restoreFromStorage() {
    final completed = _readCompletedJobIds();
    final storedStarts = _readStartTimes();
    final active = <int, DateTime>{};

    for (final entry in storedStarts.entries) {
      final jobId = int.tryParse(entry.key);
      if (jobId == null || completed.contains(jobId)) continue;
      active[jobId] = DateTime.fromMillisecondsSinceEpoch(entry.value);
    }

    if (active.isNotEmpty) {
      state = state.copyWith(activeJobStarts: active);
      _ensureTicker();
    }
  }

  bool isJobCompleted(int jobId) => _readCompletedJobIds().contains(jobId);

  bool isJobStarted(int jobId) {
    if (isJobCompleted(jobId)) return false;
    if (state.activeJobStarts.containsKey(jobId)) return true;
    return _readVerifiedMap()[_dailyKey(jobId)] == true;
  }

  int? get primaryActiveJobId {
    if (state.activeJobStarts.isEmpty) return null;
    return state.activeJobStarts.keys.first;
  }

  void ensureJobSessionHydrated(int jobId) {
    if (isJobCompleted(jobId)) return;
    if (state.activeJobStarts.containsKey(jobId)) return;

    final storedStarts = _readStartTimes();
    final storedMillis = storedStarts[jobId.toString()];
    if (storedMillis != null) {
      final updated = Map<int, DateTime>.from(state.activeJobStarts)
        ..[jobId] = DateTime.fromMillisecondsSinceEpoch(storedMillis);
      state = state.copyWith(activeJobStarts: updated);
      _ensureTicker();
      return;
    }

    if (_readVerifiedMap()[_dailyKey(jobId)] == true) {
      startJob(jobId);
    }
  }

  bool needsSafetyVerification({
    required int jobId,
    EmployeeJobStatus? status,
  }) {
    if (status == EmployeeJobStatus.completed || isJobCompleted(jobId)) {
      return false;
    }
    return !isJobStarted(jobId);
  }

  void startJob(int jobId) {
    if (isJobCompleted(jobId)) return;

    if (!state.activeJobStarts.containsKey(jobId)) {
      final updated = Map<int, DateTime>.from(state.activeJobStarts)
        ..[jobId] = DateTime.now();
      state = state.copyWith(activeJobStarts: updated);
      unawaited(_persistStartTimes());
      _ensureTicker();
    }
    unawaited(_persistVerified(jobId));
  }

  void completeJob(int jobId) {
    if (!state.activeJobStarts.containsKey(jobId) && !isJobStarted(jobId)) {
      return;
    }

    final updated = Map<int, DateTime>.from(state.activeJobStarts)
      ..remove(jobId);
    state = state.copyWith(activeJobStarts: updated);

    final completed = _readCompletedJobIds()..add(jobId);
    unawaited(_persistCompleted(completed));
    unawaited(_persistStartTimes());

    if (updated.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Maps API status using local start/completion state from the operative flow.
  EmployeeJobStatus resolveStatus({
    required int jobId,
    required EmployeeJobStatus apiStatus,
  }) {
    if (isJobCompleted(jobId) || apiStatus == EmployeeJobStatus.completed) {
      return EmployeeJobStatus.completed;
    }
    if (isJobStarted(jobId)) return EmployeeJobStatus.inProgress;
    return apiStatus;
  }

  String resolveStatusLabel({
    required int jobId,
    required String apiStatusLabel,
  }) {
    return resolveStatus(
      jobId: jobId,
      apiStatus: statusFromLabel(apiStatusLabel),
    ).label;
  }

  String resolveActionLabel({
    required int jobId,
    required EmployeeJobStatus apiStatus,
  }) {
    return switch (resolveStatus(jobId: jobId, apiStatus: apiStatus)) {
      EmployeeJobStatus.inProgress => 'Continue Job',
      EmployeeJobStatus.completed => 'View Details',
      _ => 'Start Job',
    };
  }

  EmployeeJobSummary withLocalProgress(EmployeeJobSummary job) {
    final status = resolveStatus(jobId: job.id, apiStatus: job.status);
    return EmployeeJobSummary(
      id: job.id,
      title: job.title,
      status: status,
      earning: job.earning,
      location: job.location,
      schedule: job.schedule,
      primaryActionLabel: resolveActionLabel(jobId: job.id, apiStatus: job.status),
      startDate: job.startDate,
      siteName: job.siteName,
      projectName: job.projectName,
    );
  }

  static EmployeeJobStatus statusFromLabel(String label) {
    final normalized = label.trim().toUpperCase();
    if (normalized.contains('PROGRESS')) return EmployeeJobStatus.inProgress;
    if (normalized.contains('COMPLETE')) return EmployeeJobStatus.completed;
    if (normalized.contains('UPCOMING') ||
        normalized.contains('TO DO') ||
        normalized.contains('TODO')) {
      return EmployeeJobStatus.upcoming;
    }
    return EmployeeJobStatus.pending;
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
