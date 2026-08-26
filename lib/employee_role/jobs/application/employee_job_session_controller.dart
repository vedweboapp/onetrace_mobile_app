import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

final employeeJobSessionProvider =
    StateNotifierProvider<
      EmployeeJobSessionController,
      EmployeeJobSessionState
    >((ref) => EmployeeJobSessionController(ref.read(localStorageProvider)));

final class EmployeeJobSessionState {
  const EmployeeJobSessionState({
    this.activeJobStarts = const {},
    this.pausedElapsedMs = const {},
    this.tick = 0,
  });

  final Map<int, DateTime> activeJobStarts;
  final Map<int, int> pausedElapsedMs;
  final int tick;

  bool isTimerRunning(int jobId) => activeJobStarts.containsKey(jobId);

  Duration elapsedFor(int jobId) {
    final pausedMs = pausedElapsedMs[jobId];
    if (pausedMs != null) return Duration(milliseconds: pausedMs);
    final start = activeJobStarts[jobId];
    if (start == null) return Duration.zero;
    return DateTime.now().difference(start);
  }

  EmployeeJobSessionState copyWith({
    Map<int, DateTime>? activeJobStarts,
    Map<int, int>? pausedElapsedMs,
    int? tick,
  }) {
    return EmployeeJobSessionState(
      activeJobStarts: activeJobStarts ?? this.activeJobStarts,
      pausedElapsedMs: pausedElapsedMs ?? this.pausedElapsedMs,
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

  Map<String, int> _readStartTimes() =>
      _readIntMap(LocalStorageKeys.employeeJobTimerStarts);

  Map<String, int> _readPausedElapsed() =>
      _readIntMap(LocalStorageKeys.employeeJobTimerPaused);

  Map<String, int> _readIntMap(String key) {
    final raw = _storage.getString(key);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, int>{};
      decoded.forEach((mapKey, value) {
        final millis = switch (value) {
          int v => v,
          num v => v.toInt(),
          String v => int.tryParse(v),
          _ => null,
        };
        if (millis != null) out[mapKey.toString()] = millis;
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

  Future<void> _persistPausedElapsed() async {
    final map = <String, int>{
      for (final entry in state.pausedElapsedMs.entries)
        entry.key.toString(): entry.value,
    };
    await _storage.setString(
      LocalStorageKeys.employeeJobTimerPaused,
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
    final storedPaused = _readPausedElapsed();
    final active = <int, DateTime>{};
    final paused = <int, int>{};

    for (final entry in storedPaused.entries) {
      final jobId = int.tryParse(entry.key);
      if (jobId == null || completed.contains(jobId)) continue;
      paused[jobId] = entry.value;
    }

    for (final entry in storedStarts.entries) {
      final jobId = int.tryParse(entry.key);
      if (jobId == null || completed.contains(jobId)) continue;
      if (paused.containsKey(jobId)) continue;
      active[jobId] = DateTime.fromMillisecondsSinceEpoch(entry.value);
    }

    if (active.isEmpty && paused.isEmpty) return;
    state = state.copyWith(activeJobStarts: active, pausedElapsedMs: paused);
    if (active.isNotEmpty) _ensureTicker();
  }

  bool isJobCompleted(int jobId) => _readCompletedJobIds().contains(jobId);

  bool isTimerRunning(int jobId) => state.isTimerRunning(jobId);

  bool isTimerPaused(int jobId) => state.pausedElapsedMs.containsKey(jobId);

  bool isJobStarted(int jobId) {
    if (isJobCompleted(jobId)) return false;
    if (state.activeJobStarts.containsKey(jobId)) return true;
    if (state.pausedElapsedMs.containsKey(jobId)) return true;
    return _readVerifiedMap()[_dailyKey(jobId)] == true;
  }

  void ensureJobSessionHydrated(int jobId) {
    if (isJobCompleted(jobId) || isTimerPaused(jobId)) return;
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

  Future<void> startJob(int jobId) async {
    if (isJobCompleted(jobId)) return;
    if (isTimerPaused(jobId)) {
      unawaited(_persistVerified(jobId));
      return;
    }

    if (!state.activeJobStarts.containsKey(jobId)) {
      final updated = Map<int, DateTime>.from(state.activeJobStarts)
        ..[jobId] = DateTime.now();
      state = state.copyWith(activeJobStarts: updated);
      unawaited(_persistStartTimes());
      _ensureTicker();
      unawaited(_syncTimerWithApi(jobId, action: 'start'));
    }
    unawaited(_persistVerified(jobId));
  }

  Future<void> stopJobTimer(int jobId) async {
    final start = state.activeJobStarts[jobId];
    if (start == null) return;

    final elapsedMs = DateTime.now().difference(start).inMilliseconds;
    final updatedActive = Map<int, DateTime>.from(state.activeJobStarts)
      ..remove(jobId);
    final updatedPaused = Map<int, int>.from(state.pausedElapsedMs)
      ..[jobId] = elapsedMs < 0 ? 0 : elapsedMs;
    state = state.copyWith(
      activeJobStarts: updatedActive,
      pausedElapsedMs: updatedPaused,
    );

    unawaited(_persistStartTimes());
    unawaited(_persistPausedElapsed());
    unawaited(_syncTimerWithApi(jobId, action: 'stop'));

    if (updatedActive.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> completeJob(int jobId) async {
    if (!state.activeJobStarts.containsKey(jobId) && !isJobStarted(jobId)) {
      return;
    }

    final updated = Map<int, DateTime>.from(state.activeJobStarts)
      ..remove(jobId);
    final updatedPaused = Map<int, int>.from(state.pausedElapsedMs)
      ..remove(jobId);
    state = state.copyWith(
      activeJobStarts: updated,
      pausedElapsedMs: updatedPaused,
    );

    final completed = _readCompletedJobIds()..add(jobId);
    unawaited(_persistCompleted(completed));
    unawaited(_persistStartTimes());
    unawaited(_persistPausedElapsed());
    unawaited(_syncTimerWithApi(jobId, action: 'stop'));

    if (updated.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Clears local "completed" state when new required forms are attached mid-job.
  void reopenJob(int jobId) {
    final completed = _readCompletedJobIds();
    if (!completed.remove(jobId)) return;
    unawaited(_persistCompleted(completed));
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
      primaryActionLabel: resolveActionLabel(
        jobId: job.id,
        apiStatus: job.status,
      ),
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

  Future<void> _syncTimerWithApi(int jobId, {required String action}) async {
    try {
      final dio = sl<Dio>();
      await dio.post<dynamic>(
        AppApiUrls.jobTimer(jobId),
        data: {'action': action},
      );
    } catch (_) {
      // Keep the local session state intact even if the timer API is unavailable.
    }
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

  Future<void> clearForLogout() async {
    _ticker?.cancel();
    _ticker = null;
    state = const EmployeeJobSessionState();
    await _storage.remove(LocalStorageKeys.employeeJobTimerStarts);
    await _storage.remove(LocalStorageKeys.employeeJobTimerPaused);
    await _storage.remove(LocalStorageKeys.employeeJobTimerCompleted);
    await _storage.remove(LocalStorageKeys.employeeJobSafetyVerified);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
