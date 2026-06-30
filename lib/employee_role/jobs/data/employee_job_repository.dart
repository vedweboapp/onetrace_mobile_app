import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/network/network_error_utils.dart';

import 'package:red5/employee_role/jobs/data/assigned_jobs_filter.dart';

import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/job_completion_debug_log.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/employee_role/offline/operative_offline_store.dart';
import 'package:red5/employee_role/offline/operative_sync_models.dart';

import 'package:red5/core/storage/local_storage.dart';

import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/data/job_write_payload.dart';

import 'package:red5/features/quote/data/quote_project_api_client.dart';

final employeeJobRepositoryProvider = Provider<EmployeeJobRepository>((ref) {
  return EmployeeJobRepository(
    sl<QuoteProjectApiClient>(),
    sl<LocalStorage>(),
    ref.read(operativeOfflineStoreProvider),
    sl<ConnectivityService>(),
    ref.read(operativeSyncQueueProvider),
  );
});

final class EmployeeJobsFetchResult {
  const EmployeeJobsFetchResult({
    required this.jobs,
    this.fromCache = false,
  });

  final List<EmployeeJobSummary> jobs;
  final bool fromCache;
}

final class EmployeeJobDetailFetchResult {
  const EmployeeJobDetailFetchResult({
    required this.detail,
    this.fromCache = false,
  });

  final EmployeeJobDetail detail;
  final bool fromCache;
}

final class EmployeeJobRepository {
  EmployeeJobRepository(
    this._jobsApi,
    this._storage,
    this._offlineStore,
    this._connectivity,
    this._syncQueue,
  );

  final QuoteProjectApiClient _jobsApi;
  final LocalStorage _storage;
  final OperativeOfflineStore _offlineStore;
  final ConnectivityService _connectivity;
  final OperativeSyncQueue _syncQueue;

  static final _timeFormat = DateFormat.jm();

  static final _dayFormat = DateFormat('MMM d');



  Future<List<EmployeeJobSummary>> fetchJobs() async {
    final result = await fetchJobsWithSource();
    return result.jobs;
  }

  Future<EmployeeJobsFetchResult> fetchJobsWithSource() async {
    try {
      final rows = await AssignedJobsFilter.fetchAssignedJobs(
        storage: _storage,
        fetchAll: ({assignedWorker}) =>
            _jobsApi.fetchAllJobs(assignedWorker: assignedWorker),
      );
      await _offlineStore.cacheJobList(rows);
      if (kDebugMode) {
        JobCompletionDebugLog.info('Parsed ${rows.length} job(s) from GET /jobs/');
        for (final job in rows) {
          final assignments = JobFormAssignment.listFromJobRaw(job.raw);
          if (assignments.isEmpty) continue;
          JobCompletionDebugLog.info(
            'job ${job.id} forms: '
            '${assignments.map((a) => 'template=${a.formId}→job_form=${a.jobFormId}').join(', ')}',
          );
        }
      }
      return EmployeeJobsFetchResult(
        jobs: rows.map(_mapSummary).toList(growable: false),
      );
    } catch (error) {
      if (_connectivity.isOnline && !isRecoverableNetworkError(error)) {
        rethrow;
      }
      final cached = AssignedJobsFilter.onlyAssignedToCurrentUser(
        await _offlineStore.readCachedJobList(),
        storage: _storage,
      );
      if (cached.isEmpty) rethrow;
      return EmployeeJobsFetchResult(
        jobs: cached.map(_mapSummary).toList(growable: false),
        fromCache: true,
      );
    }
  }

  Future<EmployeeJobDetail> fetchJobDetail({int? jobId}) async {
    final result = await fetchJobDetailWithSource(jobId: jobId);
    return result.detail;
  }

  Future<EmployeeJobDetailFetchResult> fetchJobDetailWithSource({
    int? jobId,
  }) async {
    if (jobId == null) {
      throw ArgumentError('jobId is required');
    }

    try {
      final job = await _jobsApi.fetchJobById(jobId.toString());
      final allowed = AssignedJobsFilter.onlyAssignedToCurrentUser(
        [job],
        storage: _storage,
      );
      if (allowed.isEmpty) {
        throw StateError('Job is not assigned to the current user.');
      }
      await _offlineStore.cacheJobDetail(job);
      return EmployeeJobDetailFetchResult(detail: _mapJobRead(job));
    } catch (error) {
      if (_connectivity.isOnline && !isRecoverableNetworkError(error)) {
        rethrow;
      }
      final cached = await _offlineStore.readCachedJobDetail(jobId);
      if (cached != null) {
        return EmployeeJobDetailFetchResult(
          detail: _mapJobRead(cached),
          fromCache: true,
        );
      }
      rethrow;
    }
  }

  /// Linked forms for a job from `GET /jobs/{id}/` → `data.forms[]`.
  Future<List<JobLinkedFormSummary>> fetchJobForms({required int jobId}) async {
    final job = await _jobsApi.fetchJobById(jobId.toString());
    return JobLinkedFormSummary.listFromJobRaw(job.raw);
  }



  EmployeeJobSummary _mapSummary(JobRead job) {

    final status = _mapStatus(job);

    return EmployeeJobSummary(
      id: job.id,
      title: job.title,
      status: status,
      earning: _formatEarning(job),
      location: _formatLocation(job),
      schedule: _formatSchedule(job),
      primaryActionLabel: _primaryActionLabel(status),
      startDate: job.startDate?.toLocal(),
      siteName: _readSiteName(job),
      projectName: _readProjectName(job),
    );

  }



  EmployeeJobDetail _mapJobRead(JobRead job) {

    final checklist = _checklistFromJob(job);

    final items = _itemsFromJob(job);

    final formAssignments = JobFormAssignment.listFromJobRaw(job.raw);
    final jobForms = JobLinkedFormSummary.listFromJobRaw(job.raw);
    final formIds = jobForms.isNotEmpty
        ? jobForms.map((form) => form.formId).toList(growable: false)
        : formAssignments.isNotEmpty
            ? formAssignments.map((a) => a.formId).toList(growable: false)
            : _formIdsFromJob(job);

    return EmployeeJobDetail(

      id: job.id,

      title: job.title,

      currentStatus: job.displayStatus.toUpperCase(),

      project: job.projectName ??

          (job.project != null ? 'Project ${job.project}' : '—'),

      client: job.clientName ??

          (job.client != null ? 'Client ${job.client}' : 'Client'),

      siteContact: _readSiteContact(job),

      block: job.siteName ?? job.displayLocation,

      plot: job.siteName ?? job.displayLocation,

      description: job.description?.trim().isNotEmpty == true

          ? job.description!.trim()

          : 'No description provided.',

      items: items,

      safetyChecklist: checklist,

      formId: _primaryFormId(job),

      formIds: formIds,

      formAssignments: formAssignments,
      jobForms: jobForms,

      projectId: job.project,

    );

  }



  List<int> _formIdsFromJob(JobRead job) {
    final ids = <int>{...job.formIds};
    if (job.form != null) ids.add(job.form!);
    return ids.toList(growable: false);
  }

  int? _primaryFormId(JobRead job) {
    if (job.form != null) return job.form;
    if (job.formIds.isNotEmpty) return job.formIds.first;
    return null;
  }

  List<EmployeeJobItem> _itemsFromJob(JobRead job) {
    final parsed = <EmployeeJobItem>[];

    void collectFrom(dynamic raw) {
      if (raw is! List || raw.isEmpty) return;
      for (final entry in raw) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(
          entry.map((k, v) => MapEntry(k.toString(), v)),
        );
        parsed.add(_mapItemRow(map));
      }
    }

    collectFrom(job.jobMeta['composite_items']);
    final plot = job.jobMeta['plot'];
    if (plot is Map) {
      collectFrom(plot['composite_items']);
    }
    collectFrom(job.raw['composite_items']);
    collectFrom(job.raw['items']);

    if (parsed.isNotEmpty) {
      return parsed;
    }

    if (job.itemName?.trim().isNotEmpty == true || job.quantity != null) {
      final name = job.itemName?.trim().isNotEmpty == true
          ? job.itemName!.trim()
          : 'Assigned item';
      return [
        EmployeeJobItem(
          name: name,
          quantityLabel: _formatQuantityLabel(
            job.quantity,
            unit: _readUnitFromMeta(job.jobMeta) ?? 'units',
          ),
          iconName: _iconForItemName(name),
        ),
      ];
    }

    return const [
      EmployeeJobItem(
        name: 'No items assigned',
        quantityLabel: '—',
        iconName: 'default',
      ),
    ];
  }

  EmployeeJobItem _mapItemRow(Map<String, dynamic> map) {
    final name = _readItemName(map);
    final qty = map['quantity'] ?? map['qty'] ?? map['amount'];
    final unit = _readUnit(map);
    return EmployeeJobItem(
      name: name,
      quantityLabel: _formatQuantityLabel(qty, unit: unit),
      iconName: _iconForItemName(name),
    );
  }

  String _readItemName(Map<String, dynamic> map) {
    for (final nestedKey in const ['item', 'composite_item', 'product']) {
      final nested = map[nestedKey];
      if (nested is! Map) continue;
      final nestedMap = Map<String, dynamic>.from(
        nested.map((k, v) => MapEntry(k.toString(), v)),
      );
      for (final key in const ['name', 'item_name', 'title']) {
        final value = nestedMap[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }

    for (final key in const ['name', 'item_name', 'title', 'label']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return 'Item';
  }

  String? _readUnit(Map<String, dynamic> map) {
    for (final key in const [
      'unit',
      'uom',
      'unit_of_measure',
      'measurement_unit',
    ]) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _readUnitFromMeta(Map<String, dynamic> meta) {
    for (final key in const ['unit', 'uom', 'unit_of_measure']) {
      final value = meta[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _formatQuantityLabel(dynamic quantity, {String? unit}) {
    if (quantity == null) return '—';
    final qtyText = quantity is num
        ? quantity % 1 == 0
            ? quantity.toInt().toString()
            : quantity.toString()
        : quantity.toString().trim();
    if (qtyText.isEmpty) return '—';

    final unitLabel = unit?.trim();
    if (unitLabel != null && unitLabel.isNotEmpty) {
      return '$qtyText $unitLabel';
    }
    return '$qtyText units';
  }

  String _iconForItemName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wire') ||
        lower.contains('cable') ||
        lower.contains('wiring')) {
      return 'wire';
    }
    if (lower.contains('smoke') ||
        lower.contains('detector') ||
        lower.contains('sensor')) {
      return 'sensor';
    }
    return 'default';
  }



  String _readSiteContact(JobRead job) {

    final siteRaw = job.raw['site'];

    if (siteRaw is Map) {

      final contacts = siteRaw['contacts'];

      if (contacts is List && contacts.isNotEmpty) {

        final first = contacts.first;

        if (first is Map) {

          final phone = first['phone']?.toString().trim();

          if (phone != null && phone.isNotEmpty) return phone;

        }

      }

    }

    final clientRaw = job.raw['client'];

    if (clientRaw is Map) {

      final phone = clientRaw['phone']?.toString().trim();

      if (phone != null && phone.isNotEmpty) return phone;

    }

    return '—';

  }



  EmployeeJobStatus _mapStatus(JobRead job) {

    if (job.completedAt != null) return EmployeeJobStatus.completed;

    final status = job.displayStatus.toUpperCase();

    if (status.contains('PROGRESS')) return EmployeeJobStatus.inProgress;

    if (status.contains('TODO') || status.contains('TO DO')) {

      return EmployeeJobStatus.upcoming;

    }

    if (status.contains('COMPLETE')) return EmployeeJobStatus.completed;

    return EmployeeJobStatus.pending;

  }



  String _formatEarning(JobRead job) {

    final total = job.total;

    if (total == null) return '—';

    return '£ ${total.toStringAsFixed(2)}';

  }



  static String? _readSiteName(JobRead job) {
    final site = job.siteName?.trim();
    if (site != null && site.isNotEmpty) return site;
    final location = job.displayLocation.trim();
    return location.isEmpty ? null : location;
  }

  static String? _readProjectName(JobRead job) {
    final project = job.projectName?.trim();
    if (project == null || project.isEmpty) return null;
    return project;
  }

  String _formatLocation(JobRead job) {
    final site = _readSiteName(job) ?? job.displayLocation;

    final project = job.projectName?.trim();

    if (project != null && project.isNotEmpty) return '$site · $project';

    return site;

  }



  String _formatSchedule(JobRead job) {

    final start = job.startDate?.toLocal();

    if (start == null) return 'Schedule TBD';

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final day = DateTime(start.year, start.month, start.day);

    final time = _timeFormat.format(start);

    if (day == today) return 'Today · $time';

    if (day == today.add(const Duration(days: 1))) return 'Tomorrow · $time';

    return '${_dayFormat.format(start)} · $time';

  }



  List<EmployeeSafetyChecklistItem> _checklistFromJob(JobRead job) {
    final checklists = JobChecklistRead.tryFromMap(job.raw['checklists']) ??
        job.checklists;
    if (checklists == null || checklists.items.isEmpty) {
      return const [];
    }

    return checklists.items
        .map(
          (item) => EmployeeSafetyChecklistItem(
            id: item.id.toString(),
            title: item.title,
            isChecked: item.isChecked,
            isRequired: item.isRequired,
            sequence: item.sequence,
          ),
        )
        .toList(growable: false);
  }

  /// Persists operative checklist completion via `PUT /jobs/{id}/`.
  Future<JobRead> updateJobChecklists({
    required int jobId,
    required List<EmployeeSafetyChecklistItem> items,
    bool fromSync = false,
  }) async {
    if (!_connectivity.isOnline && !fromSync) {
      await _syncQueue.enqueue(
        type: OperativeSyncOperationType.jobChecklistUpdate,
        payload: <String, dynamic>{
          'jobId': jobId,
          'items': _checklistPayloadMaps(items),
        },
      );
      final cached = await _offlineStore.readCachedJobDetail(jobId);
      if (cached != null) return cached;
      return JobRead(
        id: jobId,
        title: 'Job $jobId',
        raw: <String, dynamic>{'id': jobId, 'title': 'Job $jobId'},
      );
    }

    final job = await _jobsApi.fetchJobById(jobId.toString());
    final payload = JobWritePayload.buildFromJobRead(
      job,
      checklists: _checklistWritePayload(items),
    );

    JobCompletionDebugLog.api(
      label: 'Update job checklists',
      method: 'PUT',
      url: '/api/v1/jobs/$jobId/',
      request: payload,
    );

    final updated = await _jobsApi.updateJob(
      jobId: jobId.toString(),
      payload: payload,
    );
    await _offlineStore.cacheJobDetail(updated);
    return updated;
  }

  Future<JobRead> updateJobChecklistsFromPayload({
    required int jobId,
    required List<dynamic> itemsPayload,
    bool fromSync = false,
  }) async {
    final items = _checklistItemsFromPayload(itemsPayload);
    return updateJobChecklists(
      jobId: jobId,
      items: items,
      fromSync: fromSync,
    );
  }

  List<EmployeeSafetyChecklistItem> _checklistItemsFromPayload(
    List<dynamic> itemsPayload,
  ) {
    return itemsPayload
        .map((entry) {
          if (entry is! Map) return null;
          final map = Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          );
          return EmployeeSafetyChecklistItem(
            id: map['id']?.toString() ?? '',
            title: map['title']?.toString() ?? 'Checklist item',
            isChecked: map['isChecked'] == true,
            isRequired: map['isRequired'] != false,
            sequence: switch (map['sequence']) {
              int value => value,
              num value => value.toInt(),
              String value => int.tryParse(value) ?? 0,
              _ => 0,
            },
          );
        })
        .whereType<EmployeeSafetyChecklistItem>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _checklistPayloadMaps(
    List<EmployeeSafetyChecklistItem> items,
  ) =>
      items
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'title': item.title,
              'isChecked': item.isChecked,
              'isRequired': item.isRequired,
              'sequence': item.sequence,
            },
          )
          .toList(growable: false);

  List<Map<String, dynamic>> _checklistWritePayload(
    List<EmployeeSafetyChecklistItem> items,
  ) =>
      items
          .map(
            (item) => JobChecklistItemRead(
              id: int.tryParse(item.id) ?? 0,
              title: item.title,
              sequence: item.sequence,
              isRequired: item.isRequired,
              isChecked: item.isChecked,
            ).toWriteJson(),
          )
          .toList(growable: false);

  static String _primaryActionLabel(EmployeeJobStatus status) {
    return switch (status) {
      EmployeeJobStatus.inProgress => 'Continue Job',
      EmployeeJobStatus.upcoming => 'Start Job',
      EmployeeJobStatus.pending => 'Start Job',
      EmployeeJobStatus.completed => 'View Details',
    };
  }

  /// Persists operative job start to the API (`job_status` → In Progress).
  Future<JobRead> markJobStarted(int jobId, {bool fromSync = false}) async {
    if (!_connectivity.isOnline && !fromSync) {
      await _syncQueue.enqueue(
        type: OperativeSyncOperationType.jobStarted,
        payload: <String, dynamic>{'jobId': jobId},
      );
      final cached = await _offlineStore.readCachedJobDetail(jobId);
      if (cached != null) return cached;
      return JobRead(
        id: jobId,
        title: 'Job $jobId',
        raw: <String, dynamic>{'id': jobId, 'title': 'Job $jobId'},
      );
    }

    JobCompletionDebugLog.api(
      label: 'Fetch job before start',
      method: 'GET',
      url: '/api/v1/jobs/$jobId/',
    );
    final job = await _jobsApi.fetchJobById(jobId.toString());
    if (job.completedAt != null) {
      JobCompletionDebugLog.info('Job $jobId already completed — skipping start PUT');
      return job;
    }

    final currentStatus = job.displayStatus.trim().toUpperCase();
    if (currentStatus.contains('PROGRESS')) {
      JobCompletionDebugLog.info('Job $jobId already in progress on server');
      return job;
    }

    int? inProgressStatusId;
    try {
      inProgressStatusId = await _resolveJobStatusId(
        matches: (name) =>
            name.contains('in progress') ||
            (name.contains('progress') && !name.contains('not')),
      );
      JobCompletionDebugLog.info('Resolved in-progress job_status id=$inProgressStatusId');
    } catch (_) {
      JobCompletionDebugLog.info('job_status lookup failed — keeping current status id');
      inProgressStatusId = job.jobStatus;
    }

    if (inProgressStatusId == null) return job;

    final payload = JobWritePayload.buildFromJobRead(
      job,
      jobStatusOverride: inProgressStatusId,
    );

    JobCompletionDebugLog.api(
      label: 'Mark job started',
      method: 'PUT',
      url: '/api/v1/jobs/$jobId/',
      request: payload,
    );

    final updated = await _jobsApi.updateJob(jobId: jobId.toString(), payload: payload);
    await _offlineStore.cacheJobDetail(updated);

    JobCompletionDebugLog.api(
      label: 'Mark job started',
      method: 'PUT',
      url: '/api/v1/jobs/$jobId/',
      response: <String, dynamic>{
        'id': updated.id,
        'title': updated.title,
        'display_status': updated.displayStatus,
        'job_status': updated.jobStatus,
      },
    );

    return updated;
  }

  /// Persists operative job completion to the API so admin views stay in sync.
  Future<JobRead> markJobCompleted(int jobId, {bool fromSync = false}) async {
    if (!_connectivity.isOnline && !fromSync) {
      await _syncQueue.enqueue(
        type: OperativeSyncOperationType.jobCompleted,
        payload: <String, dynamic>{'jobId': jobId},
      );
      final cached = await _offlineStore.readCachedJobDetail(jobId);
      if (cached != null) return cached;
      return JobRead(
        id: jobId,
        title: 'Job $jobId',
        completedAt: DateTime.now(),
        raw: <String, dynamic>{
          'id': jobId,
          'title': 'Job $jobId',
          'completed_at': DateTime.now().toIso8601String(),
        },
      );
    }

    JobCompletionDebugLog.api(
      label: 'Fetch job before complete',
      method: 'GET',
      url: '/api/v1/jobs/$jobId/',
    );
    final job = await _jobsApi.fetchJobById(jobId.toString());
    if (job.completedAt != null) {
      JobCompletionDebugLog.info('Job $jobId already completed — skipping PUT');
      return job;
    }

    int? completedStatusId = job.jobStatus;
    try {
      completedStatusId = await _resolveJobStatusId(
        matches: (name) => name.contains('complete') && !name.contains('incomplete'),
      );
      JobCompletionDebugLog.info('Resolved completed job_status id=$completedStatusId');
    } catch (_) {
      JobCompletionDebugLog.info('job_status lookup failed — using completed_at only');
    }

    final payload = JobWritePayload.buildFromJobRead(
      job,
      completedAt: DateTime.now(),
      jobStatusOverride: completedStatusId,
    );

    JobCompletionDebugLog.api(
      label: 'Mark job completed',
      method: 'PUT',
      url: '/api/v1/jobs/$jobId/',
      request: payload,
    );

    final updated = await _jobsApi.updateJob(jobId: jobId.toString(), payload: payload);
    await _offlineStore.cacheJobDetail(updated);

    JobCompletionDebugLog.api(
      label: 'Mark job completed',
      method: 'PUT',
      url: '/api/v1/jobs/$jobId/',
      response: <String, dynamic>{
        'id': updated.id,
        'title': updated.title,
        'completed_at': updated.completedAt?.toUtc().toIso8601String(),
        'display_status': updated.displayStatus,
        'job_status': updated.jobStatus,
      },
    );

    return updated;
  }

  Future<int?> _resolveJobStatusId({
    required bool Function(String normalizedName) matches,
  }) async {
    final statuses = await _jobsApi.fetchJobStatusOptions();
    for (final status in statuses) {
      final name = status.name.trim().toLowerCase();
      if (matches(name)) return status.id;
    }
    return null;
  }

}


