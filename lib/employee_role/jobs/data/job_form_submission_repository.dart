import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/database/technician_form_database.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/employee_role/jobs/data/employee_job_forms_api_client.dart';
import 'package:red5/employee_role/jobs/data/job_completion_debug_log.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
final jobFormSubmissionRepositoryProvider =
    Provider<JobFormSubmissionRepository>((ref) {
  return JobFormSubmissionRepository(
    api: sl<EmployeeJobFormsApiClient>(),
    database: sl<TechnicianFormDatabase>(),
    connectivity: sl<ConnectivityService>(),
    jobsApi: sl<QuoteProjectApiClient>(),
  );
});

final class JobFormSubmissionResult {
  const JobFormSubmissionResult({
    required this.syncedToServer,
    required this.queuedOffline,
    this.serverSubmission,
  });

  final bool syncedToServer;
  final bool queuedOffline;
  final SubmittedJobForm? serverSubmission;
}

final class JobFormSubmissionRepository {
  JobFormSubmissionRepository({
    required EmployeeJobFormsApiClient api,
    required TechnicianFormDatabase database,
    required ConnectivityService connectivity,
    required QuoteProjectApiClient jobsApi,
  })  : _api = api,
        _database = database,
        _connectivity = connectivity,
        _jobsApi = jobsApi;

  final EmployeeJobFormsApiClient _api;
  final TechnicianFormDatabase _database;
  final ConnectivityService _connectivity;
  final QuoteProjectApiClient _jobsApi;

  static String _localIdFor({required int jobId, required int formId}) =>
      'job_${jobId}_form_$formId';

  /// Resolves the job-form link id (`job_form_id` in API body), not the template id.
  Future<int?> resolveJobFormId({
    required int jobId,
    required int formTemplateId,
    List<JobFormAssignment> assignments = const [],
  }) async {
    for (final assignment in assignments) {
      if (assignment.formId == formTemplateId) return assignment.jobFormId;
    }

    final cachedJobFormId = await _database.readJobFormId(
      jobId: jobId,
      formId: formTemplateId,
    );
    if (cachedJobFormId != null && cachedJobFormId > 0) {
      return cachedJobFormId;
    }

    if (_connectivity.isOnline) {
      try {
        final linked = await _api.fetchJobLinkedForms(jobId);
        for (final row in linked) {
          if (row.formId == formTemplateId) {
            final linkId = row.jobFormId;
            if (linkId != null && linkId > 0) return linkId;
          }
        }

        final submitted = await _api.fetchSubmittedJobForms(jobId);
        for (final row in submitted) {
          if (row.formId == formTemplateId && row.jobFormId > 0) {
            return row.jobFormId;
          }
        }

        final job = await _jobsApi.fetchJobById(jobId.toString());
        final fromJob = JobFormAssignment.listFromJobRaw(job.raw);
        for (final assignment in fromJob) {
          if (assignment.formId == formTemplateId && assignment.jobFormId > 0) {
            await cacheJobFormLinks(jobId: jobId, assignments: fromJob);
            return assignment.jobFormId;
          }
        }
      } on DioException catch (error) {
        if (!_isNetworkError(error)) rethrow;
      }
    }

    return null;
  }

  /// Stores `job_form_id` (+ optional `submission_id`) from `GET /jobs/{id}/`.
  Future<void> cacheJobFormLinks({
    required int jobId,
    required List<JobFormAssignment> assignments,
  }) async {
    for (final assignment in assignments) {
      if (assignment.jobFormId <= 0 || assignment.formId <= 0) continue;

      await _database.upsertJobFormLink(
        jobId: jobId,
        formId: assignment.formId,
        jobFormId: assignment.jobFormId,
        submissionId: assignment.submissionId,
      );

      final existing = await _database.readSubmission(
        jobId: jobId,
        formId: assignment.formId,
      );
      if (existing == null) continue;

      final nextSubmissionId = assignment.submissionId ?? existing.serverSubmissionId;
      if (existing.jobFormId == assignment.jobFormId &&
          existing.serverSubmissionId == nextSubmissionId) {
        continue;
      }

      await _database.upsertSubmission(
        CachedJobFormSubmission(
          localId: existing.localId,
          jobId: existing.jobId,
          formId: existing.formId,
          jobFormId: assignment.jobFormId,
          status: existing.status,
          remarks: existing.remarks,
          values: existing.values,
          syncStatus: existing.syncStatus,
          serverSubmissionId: nextSubmissionId,
          lastError: existing.lastError,
          updatedAt: DateTime.now(),
          createdAt: existing.createdAt,
        ),
      );
    }

    if (kDebugMode && assignments.isNotEmpty) {
      debugPrint(
        '[JOB-FORM-LINK] cached ${assignments.length} link(s) for job=$jobId',
      );
    }
  }

  Future<List<JobFormAssignment>> _mergeAssignments({
    required int jobId,
    List<JobFormAssignment> assignments = const [],
  }) async {
    final cached = await _database.listJobFormLinks(jobId);
    final merged = <int, JobFormAssignment>{
      for (final link in cached) link.formId: link,
    };
    for (final assignment in assignments) {
      merged[assignment.formId] = assignment;
    }
    return merged.values.toList(growable: false);
  }

  Future<List<JobFormAssignment>> cachedAssignmentsForJob(int jobId) =>
      _database.listJobFormLinks(jobId);

  /// Re-fetches `GET /jobs/{id}/` and caches forms[].job_form_id links.
  Future<List<JobFormAssignment>> refreshJobFormLinksFromApi(int jobId) async {
    if (!_connectivity.isOnline) {
      return _database.listJobFormLinks(jobId);
    }

    try {
      JobCompletionDebugLog.api(
        label: 'Refresh job form links',
        method: 'GET',
        url: '/api/v1/jobs/$jobId/',
      );
      final job = await _jobsApi.fetchJobById(jobId.toString());
      var assignments = JobFormAssignment.listFromJobRaw(job.raw);

      if (kDebugMode) {
        JobCompletionDebugLog.info(
          'job raw keys: ${job.raw.keys.toList()} | '
          'forms=${job.raw['forms']} | job_forms=${job.raw['job_forms']} | '
          'resolved assignments: ${assignments.length}',
        );
      }

      if (assignments.isNotEmpty) {
        await cacheJobFormLinks(jobId: jobId, assignments: assignments);
        JobCompletionDebugLog.api(
          label: 'Refresh job form links',
          method: 'GET',
          url: '/api/v1/jobs/$jobId/',
          response: assignments
              .map(
                (a) => <String, Object?>{
                  'project_form_id': a.formId,
                  'job_form_id': a.jobFormId,
                  'submission_id': a.submissionId,
                },
              )
              .toList(growable: false),
        );
      }
      return _mergeAssignments(jobId: jobId, assignments: assignments);
    } catch (error) {
      JobCompletionDebugLog.api(
        label: 'Refresh job form links FAILED',
        method: 'GET',
        url: '/api/v1/jobs/$jobId/',
        error: error,
      );
      return _database.listJobFormLinks(jobId);
    }
  }

  Future<CachedJobFormSubmission> _repairPendingSubmission(
    CachedJobFormSubmission row,
    List<JobFormAssignment> links, {
    bool allowJobFormFallback = false,
  }) async {
    if (links.isEmpty) {
      links = await _database.listJobFormLinks(row.jobId);
    }

    final match = _pickAssignmentForRow(
      row,
      links,
      allowJobFormFallback: allowJobFormFallback,
    );

    var jobFormId = row.jobFormId;
    var formId = row.formId;
    var submissionId = row.serverSubmissionId;

    if (match != null) {
      jobFormId = match.jobFormId;
      formId = match.formId;
      if (row.syncStatus == JobFormSubmissionSyncStatus.synced) {
        submissionId = submissionId ?? match.submissionId;
      } else {
        submissionId = null;
      }
    } else if (jobFormId <= 0) {
      jobFormId = await _resolveStoredJobFormId(
        jobId: row.jobId,
        formTemplateId: row.formId,
        existing: row,
        assignments: links,
      );
    }

    if (jobFormId <= 0) return row;

    final localId = _localIdFor(jobId: row.jobId, formId: formId);
    final repaired = CachedJobFormSubmission(
      localId: localId,
      jobId: row.jobId,
      formId: formId,
      jobFormId: jobFormId,
      status: row.status,
      remarks: row.remarks,
      values: row.values,
      syncStatus: row.syncStatus,
      serverSubmissionId: submissionId,
      lastError: row.lastError,
      updatedAt: DateTime.now(),
      createdAt: row.createdAt,
    );

    if (repaired.localId != row.localId) {
      await _database.deleteSubmission(row.localId);
    }
    await _database.upsertSubmission(repaired);
    return repaired;
  }

  JobFormAssignment? _pickAssignmentForRow(
    CachedJobFormSubmission row,
    List<JobFormAssignment> links, {
    bool allowJobFormFallback = false,
  }) {
    if (links.isEmpty) return null;

    for (final link in links) {
      if (link.formId == row.formId) return link;
    }
    for (final link in links) {
      if (link.jobFormId == row.formId) return link;
    }
    if (links.length == 1) return links.first;
    if (allowJobFormFallback) return links.first;
    return null;
  }

  Future<int?> resolveSubmissionId({
    required int jobId,
    required int formTemplateId,
  }) async {
    final local = await _database.readSubmission(
      jobId: jobId,
      formId: formTemplateId,
    );
    return _resolveSubmissionIdForForm(
      jobId: jobId,
      formTemplateId: formTemplateId,
      local: local,
    );
  }

  Future<JobFormSubmissionResult> saveAndSubmit({
    required int jobId,
    required int formTemplateId,
    required int jobFormId,
    required List<JobFormFieldValue> values,
    String status = 'submitted',
    String? remarks,
    int? submissionId,
  }) async {
    if (jobFormId <= 0) {
      throw StateError(
        'Could not resolve job_form_id for form $formTemplateId.',
      );
    }

    final existing = await _database.readSubmission(
      jobId: jobId,
      formId: formTemplateId,
    );

    final now = DateTime.now();
    final localId = existing?.localId ??
        _localIdFor(jobId: jobId, formId: formTemplateId);

    var cached = CachedJobFormSubmission(
      localId: localId,
      jobId: jobId,
      formId: formTemplateId,
      jobFormId: jobFormId,
      status: status,
      remarks: remarks,
      values: values,
      syncStatus: JobFormSubmissionSyncStatus.pending,
      serverSubmissionId: submissionId ?? existing?.serverSubmissionId,
      updatedAt: now,
      createdAt: existing?.createdAt ?? now,
    );
    await _database.upsertSubmission(cached);

    if (!_connectivity.isOnline) {
      JobCompletionDebugLog.localSave(
        label: 'Form submit (offline)',
        jobId: jobId,
        projectFormId: formTemplateId,
        jobFormId: jobFormId,
        status: status,
        remarks: remarks,
        submissionId: submissionId,
        values: values.map((v) => v.toJson()).toList(growable: false),
      );
      return const JobFormSubmissionResult(
        syncedToServer: false,
        queuedOffline: true,
      );
    }

    try {
      final payload = JobFormSubmitPayload(
        jobFormId: jobFormId,
        status: status,
        remarks: remarks,
        values: values,
      );
      final server = await _api.submitJobForm(
        jobId: jobId,
        payload: payload,
      );
      final serverSubmissionId =
          server.resolvedSubmissionId ?? (server.id == 0 ? null : server.id);
      cached = CachedJobFormSubmission(
        localId: localId,
        jobId: jobId,
        formId: formTemplateId,
        jobFormId: jobFormId,
        status: status,
        remarks: remarks,
        values: values,
        syncStatus: JobFormSubmissionSyncStatus.synced,
        serverSubmissionId: serverSubmissionId,
        updatedAt: DateTime.now(),
        createdAt: existing?.createdAt ?? now,
      );
      await _database.upsertSubmission(cached);
      return JobFormSubmissionResult(
        syncedToServer: true,
        queuedOffline: false,
        serverSubmission: server,
      );
    } on DioException catch (error) {
      if (!_isNetworkError(error)) rethrow;
      return const JobFormSubmissionResult(
        syncedToServer: false,
        queuedOffline: true,
      );
    }
  }

  Future<JobFormSubmissionResult> updateSubmission({
    required int jobId,
    required int formTemplateId,
    required int jobFormId,
    required int submissionId,
    required List<JobFormFieldValue> values,
    String status = 'submitted',
    String? remarks,
  }) async {
    final now = DateTime.now();
    final existing = await _database.readSubmission(
      jobId: jobId,
      formId: formTemplateId,
    );
    final localId = existing?.localId ??
        _localIdFor(jobId: jobId, formId: formTemplateId);

    var cached = CachedJobFormSubmission(
      localId: localId,
      jobId: jobId,
      formId: formTemplateId,
      jobFormId: jobFormId,
      status: status,
      remarks: remarks,
      values: values,
      syncStatus: JobFormSubmissionSyncStatus.pending,
      serverSubmissionId: submissionId,
      updatedAt: now,
      createdAt: existing?.createdAt ?? now,
    );
    await _database.upsertSubmission(cached);

    if (!_connectivity.isOnline) {
      return const JobFormSubmissionResult(
        syncedToServer: false,
        queuedOffline: true,
      );
    }

    try {
      final server = await _api.updateSubmittedJobForm(
        jobId: jobId,
        submissionId: submissionId,
        payload: JobFormUpdatePayload(
          status: status,
          remarks: remarks,
          values: values,
        ),
      );
      final serverSubmissionId =
          server.resolvedSubmissionId ?? submissionId;
      cached = CachedJobFormSubmission(
        localId: localId,
        jobId: jobId,
        formId: formTemplateId,
        jobFormId: jobFormId,
        status: status,
        remarks: remarks,
        values: values,
        syncStatus: JobFormSubmissionSyncStatus.synced,
        serverSubmissionId: serverSubmissionId,
        updatedAt: DateTime.now(),
        createdAt: existing?.createdAt ?? now,
      );
      await _database.upsertSubmission(cached);
      return JobFormSubmissionResult(
        syncedToServer: true,
        queuedOffline: false,
        serverSubmission: server,
      );
    } on DioException catch (error) {
      if (!_isNetworkError(error)) rethrow;
      return const JobFormSubmissionResult(
        syncedToServer: false,
        queuedOffline: true,
      );
    }
  }

  Future<void> saveDraft({
    required int jobId,
    required int formTemplateId,
    required List<JobFormFieldValue> values,
    int? jobFormId,
    String? remarks,
    List<JobFormAssignment> assignments = const [],
  }) async {
    final now = DateTime.now();
    final existing = await _database.readSubmission(
      jobId: jobId,
      formId: formTemplateId,
    );
    final resolvedRemarks = remarks?.trim().isNotEmpty == true
        ? remarks!.trim()
        : existing?.remarks;
    var resolvedJobFormId = await _resolveStoredJobFormId(
      jobId: jobId,
      formTemplateId: formTemplateId,
      jobFormId: jobFormId,
      existing: existing,
      assignments: assignments,
      allowRemoteLookup: _connectivity.isOnline,
    );
    if (resolvedJobFormId <= 0 && _connectivity.isOnline) {
      await refreshJobFormLinksFromApi(jobId);
      resolvedJobFormId = await _resolveStoredJobFormId(
        jobId: jobId,
        formTemplateId: formTemplateId,
        jobFormId: jobFormId,
        existing: existing,
        assignments: assignments,
        allowRemoteLookup: true,
      );
    }
    final submissionId =
        existing?.syncStatus == JobFormSubmissionSyncStatus.synced
            ? existing?.serverSubmissionId
            : null;

    var cached = CachedJobFormSubmission(
      localId: existing?.localId ??
          _localIdFor(jobId: jobId, formId: formTemplateId),
      jobId: jobId,
      formId: formTemplateId,
      jobFormId: resolvedJobFormId,
      status: 'draft',
      remarks: resolvedRemarks,
      values: values,
      syncStatus: existing?.syncStatus == JobFormSubmissionSyncStatus.synced
          ? JobFormSubmissionSyncStatus.synced
          : JobFormSubmissionSyncStatus.pending,
      serverSubmissionId: submissionId,
      updatedAt: now,
      createdAt: existing?.createdAt ?? now,
    );
    await _database.upsertSubmission(cached);

    if (resolvedJobFormId > 0) {
      await _database.upsertJobFormLink(
        jobId: jobId,
        formId: formTemplateId,
        jobFormId: resolvedJobFormId,
        submissionId: submissionId,
      );
    }

    JobCompletionDebugLog.localSave(
      label: 'Draft auto-save',
      jobId: jobId,
      projectFormId: formTemplateId,
      jobFormId: resolvedJobFormId,
      status: 'draft',
      remarks: resolvedRemarks,
      submissionId: submissionId,
      values: values.map((v) => v.toJson()).toList(growable: false),
    );
  }

  /// Saves form field values to SQLite only. API sync happens on Submit Form.
  Future<JobFormSubmissionResult> saveFormLocally({
    required int jobId,
    required int formTemplateId,
    required List<JobFormFieldValue> values,
    int? jobFormId,
    String? remarks,
    int? submissionId,
    String status = 'submitted',
    List<JobFormAssignment> assignments = const [],
  }) async {
    final existing = await _database.readSubmission(
      jobId: jobId,
      formId: formTemplateId,
    );
    var resolvedJobFormId = await _resolveStoredJobFormId(
      jobId: jobId,
      formTemplateId: formTemplateId,
      jobFormId: jobFormId,
      existing: existing,
      assignments: assignments,
      allowRemoteLookup: _connectivity.isOnline,
    );
    if (resolvedJobFormId <= 0 && _connectivity.isOnline) {
      await refreshJobFormLinksFromApi(jobId);
      resolvedJobFormId = await _resolveStoredJobFormId(
        jobId: jobId,
        formTemplateId: formTemplateId,
        jobFormId: jobFormId,
        existing: existing,
        assignments: assignments,
        allowRemoteLookup: true,
      );
    }
    if (resolvedJobFormId <= 0) {
      throw StateError(
        'Could not resolve job_form_id for form $formTemplateId.',
      );
    }
    final resolvedSubmissionId = submissionId ??
        (existing?.syncStatus == JobFormSubmissionSyncStatus.synced
            ? existing?.serverSubmissionId
            : null);

    final now = DateTime.now();
    final localId = existing?.localId ??
        _localIdFor(jobId: jobId, formId: formTemplateId);

    var cached = CachedJobFormSubmission(
      localId: localId,
      jobId: jobId,
      formId: formTemplateId,
      jobFormId: resolvedJobFormId,
      status: status,
      remarks: remarks,
      values: values,
      syncStatus: JobFormSubmissionSyncStatus.pending,
      serverSubmissionId: resolvedSubmissionId,
      updatedAt: now,
      createdAt: existing?.createdAt ?? now,
    );
    await _database.upsertSubmission(cached);

    if (resolvedJobFormId > 0) {
      await _database.upsertJobFormLink(
        jobId: jobId,
        formId: formTemplateId,
        jobFormId: resolvedJobFormId,
        submissionId: resolvedSubmissionId,
      );
    }

    JobCompletionDebugLog.localSave(
      label: 'Form saved',
      jobId: jobId,
      projectFormId: formTemplateId,
      jobFormId: resolvedJobFormId,
      status: status,
      remarks: remarks,
      submissionId: resolvedSubmissionId,
      values: values.map((v) => v.toJson()).toList(growable: false),
    );

    return const JobFormSubmissionResult(
      syncedToServer: false,
      queuedOffline: true,
    );
  }

  Future<String?> loadSavedRemarks({
    required int jobId,
    required int formId,
  }) async {
    final local = await _database.readSubmission(jobId: jobId, formId: formId);
    if (local?.remarks?.trim().isNotEmpty == true) return local!.remarks;

    if (!_connectivity.isOnline) return null;

    final remote = await fetchSubmittedFormRemote(
      jobId: jobId,
      formTemplateId: formId,
    );
    return remote?.remarks;
  }

  Future<List<JobFormFieldValue>?> loadSavedValues({
    required int jobId,
    required int formId,
  }) async {
    final local = await _database.readSubmission(jobId: jobId, formId: formId);
    if (local != null && local.values.isNotEmpty) {
      return local.values;
    }

    if (!_connectivity.isOnline) return null;

    final submissionId = await _resolveSubmissionIdForForm(
      jobId: jobId,
      formTemplateId: formId,
      local: local,
    );
    if (submissionId == null) return null;

    try {
      final remote = await _api.fetchSubmittedJobForm(
        jobId: jobId,
        submissionId: submissionId,
      );
      if (remote.values.isNotEmpty) return remote.values;
    } on DioException catch (error) {
      if (!_isNetworkError(error) && !_isMissingSubmission(error)) rethrow;
    }

    return null;
  }

  /// Loads the latest submission values for editing an existing form.
  ///
  /// Prefers the server copy when online so completed jobs show submitted data.
  Future<({List<JobFormFieldValue> values, String? remarks})?>
      loadSubmissionForEdit({
    required int jobId,
    required int formTemplateId,
    int? submissionId,
    List<JobFormAssignment> assignments = const [],
  }) async {
    final resolvedSubmissionId = submissionId ??
        await resolveSubmissionId(
          jobId: jobId,
          formTemplateId: formTemplateId,
        );
    final local = await _database.readSubmission(
      jobId: jobId,
      formId: formTemplateId,
    );

    if (resolvedSubmissionId != null &&
        resolvedSubmissionId > 0 &&
        _connectivity.isOnline) {
      try {
        final remote = await _api.fetchSubmittedJobForm(
          jobId: jobId,
          submissionId: resolvedSubmissionId,
        );
        final jobFormId = await _resolveStoredJobFormId(
          jobId: jobId,
          formTemplateId: formTemplateId,
          jobFormId: remote.jobFormId,
          existing: local,
          assignments: assignments,
        );
        await _database.upsertSubmission(
          CachedJobFormSubmission(
            localId: local?.localId ??
                _localIdFor(jobId: jobId, formId: formTemplateId),
            jobId: jobId,
            formId: formTemplateId,
            jobFormId: jobFormId,
            status: remote.status,
            remarks: remote.remarks,
            values: remote.values,
            syncStatus: JobFormSubmissionSyncStatus.synced,
            serverSubmissionId: resolvedSubmissionId,
            updatedAt: DateTime.now(),
            createdAt: local?.createdAt ?? DateTime.now(),
          ),
        );
        return (values: remote.values, remarks: remote.remarks);
      } on DioException catch (error) {
        if (!_isNetworkError(error) && !_isMissingSubmission(error)) rethrow;
      }
    }

    if (local != null && local.values.isNotEmpty) {
      return (values: local.values, remarks: local.remarks);
    }

    final saved = await loadSavedValues(jobId: jobId, formId: formTemplateId);
    if (saved == null || saved.isEmpty) return null;
    return (values: saved, remarks: local?.remarks);
  }

  Future<List<JobLinkedFormSummary>> fetchLinkedFormsRemote(int jobId) async {
    if (!_connectivity.isOnline) return const [];
    return _api.fetchJobLinkedForms(jobId);
  }

  Future<List<SubmittedJobForm>> fetchSubmittedFormsRemote(int jobId) async {
    if (!_connectivity.isOnline) return const [];
    return _api.fetchSubmittedJobForms(jobId);
  }

  Future<SubmittedJobForm?> fetchSubmittedFormRemote({
    required int jobId,
    required int formTemplateId,
  }) async {
    if (!_connectivity.isOnline) return null;

    final submissionId = await _resolveSubmissionIdForForm(
      jobId: jobId,
      formTemplateId: formTemplateId,
    );
    if (submissionId == null) return null;

    try {
      return await _api.fetchSubmittedJobForm(
        jobId: jobId,
        submissionId: submissionId,
      );
    } on DioException catch (error) {
      if (_isNetworkError(error) || _isMissingSubmission(error)) return null;
      rethrow;
    }
  }

  Future<Set<int>> completedFormIdsForJob({
    required int jobId,
    required List<int> formIds,
    List<JobFormAssignment> assignments = const [],
  }) async {
    final completed = <int>{};

    final localRows = await _database.listSubmissionsForJob(jobId);
    for (final row in localRows) {
      if (!formIds.contains(row.formId)) continue;
      if (row.isSubmitted &&
          (row.syncStatus == JobFormSubmissionSyncStatus.synced ||
              row.syncStatus == JobFormSubmissionSyncStatus.pending)) {
        completed.add(row.formId);
      }
    }

    if (_connectivity.isOnline) {
      try {
        final linked = await _api.fetchJobLinkedForms(jobId);
        for (final row in linked) {
          if (row.isSubmitted && formIds.contains(row.formId)) {
            completed.add(row.formId);
          }
        }

        final remote = await _api.fetchSubmittedJobForms(jobId);
        for (final submission in remote) {
          if (!submission.isSubmitted) continue;
          final formId = _resolveFormId(submission, assignments);
          if (formId != null && formIds.contains(formId)) {
            completed.add(formId);
          }
        }
      } on DioException catch (error) {
        if (!_isNetworkError(error)) rethrow;
      }
    }

    return completed;
  }

  /// Syncs locally saved forms to `POST /jobs/{jobId}/submit-form/` (Submit Form tap).
  ///
  /// POSTs the full submit-form payload (`job_form_id`, `status`, `remarks`,
  /// `values`) for each locally saved form. Throws if offline or sync fails.
  Future<void> syncPendingSubmissionsForJob({
    required int jobId,
    List<JobFormAssignment> assignments = const [],
  }) async {
    if (!_connectivity.isOnline) {
      throw StateError(
        'No internet connection. Connect and try again to complete the job.',
      );
    }

    final apiAssignments = await refreshJobFormLinksFromApi(jobId);
    final mergedAssignments = await _mergeAssignments(
      jobId: jobId,
      assignments: [...assignments, ...apiAssignments],
    );
    final repairLinks =
        apiAssignments.isNotEmpty ? apiAssignments : mergedAssignments;

    final pending = await _database.listPendingSubmissionsForJob(jobId);
    final toSync = pending.where((row) => row.isSubmitted).toList();

    JobCompletionDebugLog.info(
      'Pending forms: ${pending.length} | to sync: ${toSync.length} | '
      'links: ${mergedAssignments.map((a) => '${a.formId}→${a.jobFormId}').join(', ')}',
    );

    if (toSync.isEmpty) {
      JobCompletionDebugLog.info('No local forms — submit-form API skipped');
    } else {
      JobCompletionDebugLog.banner(
        'API CALL | ${toSync.length} form(s) → POST submit-form (from SQLite)',
      );
    }

    final failures = <String>[];

    for (final row in toSync) {
      try {
        final repaired = await _repairPendingSubmission(
          row,
          repairLinks,
          allowJobFormFallback:
              toSync.length == 1 && repairLinks.isNotEmpty,
        );
        await _postSubmitFormFromSqlite(repaired);
      } catch (error) {
        failures.add(
          error is StateError
              ? error.message
              : 'Form ${row.formId}: ${error.toString()}',
        );
      }
    }

    if (failures.isNotEmpty) {
      throw StateError(failures.join('\n'));
    }

    if (toSync.isNotEmpty) {
      JobCompletionDebugLog.info('Synced ${toSync.length} form(s) to API');
    }
  }

  Future<int> syncPendingSubmissions() async {
    if (!_connectivity.isOnline) return 0;

    final pending = await _database.listPendingSubmissions();
    var syncedCount = 0;

    for (final row in pending) {
      if (!row.isSubmitted) continue;
      try {
        await _syncPendingRow(row);
        syncedCount++;
      } on DioException catch (error) {
        if (_isNetworkError(error)) continue;
        await _database.upsertSubmission(
          CachedJobFormSubmission(
            localId: row.localId,
            jobId: row.jobId,
            formId: row.formId,
            jobFormId: row.jobFormId,
            status: row.status,
            remarks: row.remarks,
            values: row.values,
            syncStatus: JobFormSubmissionSyncStatus.failed,
            serverSubmissionId: row.serverSubmissionId,
            lastError: error.message,
            updatedAt: DateTime.now(),
            createdAt: row.createdAt,
          ),
        );
      }
    }

    return syncedCount;
  }

  /// Reads a pending SQLite row and POSTs it to `jobs/{jobId}/submit-form/`.
  Future<void> _postSubmitFormFromSqlite(CachedJobFormSubmission row) async {
    if (row.jobFormId <= 0) {
      throw StateError(
        'Could not resolve job_form_id for form ${row.formId}. '
        'Re-open the job and try again.',
      );
    }

    final payload = JobFormSubmitPayload(
      jobFormId: row.jobFormId,
      status: row.status.isNotEmpty ? row.status : 'submitted',
      remarks: row.remarks,
      values: row.values,
    );

    JobCompletionDebugLog.info(
      'SQLite → POST | job_id=${row.jobId} | job_form_id=${row.jobFormId} | '
      '${row.values.length} field(s)',
    );
    JobCompletionDebugLog.api(
      label: 'Submit job form (from SQLite)',
      method: 'POST',
      url: '/api/v1/jobs/${row.jobId}/submit-form/',
      request: payload.toJson(),
    );

    final server = await _api.submitJobForm(
      jobId: row.jobId,
      payload: payload,
    );

    final serverSubmissionId = server.resolvedSubmissionId ??
        (server.id == 0 ? null : server.id);

    await _database.upsertSubmission(
      CachedJobFormSubmission(
        localId: row.localId,
        jobId: row.jobId,
        formId: row.formId,
        jobFormId: row.jobFormId,
        status: row.status,
        remarks: row.remarks,
        values: row.values,
        syncStatus: JobFormSubmissionSyncStatus.synced,
        serverSubmissionId: serverSubmissionId,
        lastError: null,
        updatedAt: DateTime.now(),
        createdAt: row.createdAt,
      ),
    );

    JobCompletionDebugLog.api(
      label: 'Submit job form (from SQLite)',
      method: 'POST',
      url: '/api/v1/jobs/${row.jobId}/submit-form/',
      response: <String, dynamic>{
        'sqlite_sync_status': 'synced',
        'server_submission_id': serverSubmissionId,
        'id': server.id,
        'job_form_id': server.jobFormId,
        'status': server.status,
      },
    );
  }

  Future<void> _syncPendingRow(
    CachedJobFormSubmission row, {
    List<JobFormAssignment> assignments = const [],
  }) async {
    var jobFormId = row.jobFormId;
    var formId = row.formId;
    JobFormAssignment? match;
    if (jobFormId <= 0) {
      final links = assignments.isNotEmpty
          ? assignments
          : await _database.listJobFormLinks(row.jobId);
      match = _pickAssignmentForRow(
        row,
        links,
        allowJobFormFallback: true,
      );
      if (match != null) {
        jobFormId = match.jobFormId;
        formId = match.formId;
      } else {
        jobFormId = await _resolveStoredJobFormId(
          jobId: row.jobId,
          formTemplateId: row.formId,
          existing: row,
          assignments: links,
        );
      }
      if (jobFormId <= 0) {
        throw StateError(
          'Could not resolve job_form_id for form ${row.formId}. '
          'Re-open the job and try again.',
        );
      }
      if (jobFormId != row.jobFormId || formId != row.formId) {
        row = CachedJobFormSubmission(
          localId: _localIdFor(jobId: row.jobId, formId: formId),
          jobId: row.jobId,
          formId: formId,
          jobFormId: jobFormId,
          status: row.status,
          remarks: row.remarks,
          values: row.values,
          syncStatus: row.syncStatus,
          serverSubmissionId: row.serverSubmissionId ?? match?.submissionId,
          lastError: row.lastError,
          updatedAt: DateTime.now(),
          createdAt: row.createdAt,
        );
      }
    }

    final submissionId = row.serverSubmissionId ?? match?.submissionId;
    final SubmittedJobForm server;
    if (submissionId != null && submissionId > 0) {
      final updatePayload = JobFormUpdatePayload(
        status: row.status,
        remarks: row.remarks,
        values: row.values,
      );
      JobCompletionDebugLog.api(
        label: 'Update submitted form',
        method: 'PUT',
        url: '/api/v1/jobs/${row.jobId}/submitted-forms/$submissionId/update/',
        request: updatePayload.toJson(),
      );
      server = await _api.updateSubmittedJobForm(
        jobId: row.jobId,
        submissionId: submissionId,
        payload: updatePayload,
      );
    } else {
      final submitPayload = JobFormSubmitPayload(
        jobFormId: jobFormId,
        status: row.status,
        remarks: row.remarks,
        values: row.values,
      );
      JobCompletionDebugLog.api(
        label: 'Submit job form',
        method: 'POST',
        url: '/api/v1/jobs/${row.jobId}/submit-form/',
        request: submitPayload.toJson(),
      );
      server = await _api.submitJobForm(
        jobId: row.jobId,
        payload: submitPayload,
      );
    }

    JobCompletionDebugLog.api(
      label: submissionId != null && submissionId > 0
          ? 'Update submitted form'
          : 'Submit job form',
      method: submissionId != null && submissionId > 0 ? 'PUT' : 'POST',
      url: submissionId != null && submissionId > 0
          ? '/api/v1/jobs/${row.jobId}/submitted-forms/$submissionId/update/'
          : '/api/v1/jobs/${row.jobId}/submit-form/',
      response: <String, dynamic>{
        'id': server.id,
        'submission_id': server.resolvedSubmissionId,
        'job_form_id': server.jobFormId,
        'form_id': server.formId,
        'status': server.status,
      },
    );
    final serverSubmissionId = server.resolvedSubmissionId ??
        (server.id == 0 ? row.serverSubmissionId : server.id);
    await _database.upsertSubmission(
      CachedJobFormSubmission(
        localId: row.localId,
        jobId: row.jobId,
        formId: row.formId,
        jobFormId: jobFormId,
        status: row.status,
        remarks: row.remarks,
        values: row.values,
        syncStatus: JobFormSubmissionSyncStatus.synced,
        serverSubmissionId: serverSubmissionId,
        updatedAt: DateTime.now(),
        createdAt: row.createdAt,
      ),
    );
  }

  int? resolveJobFormIdFromLists({
    required int formTemplateId,
    required List<JobFormAssignment> assignments,
    List<SubmittedJobForm> submittedForms = const [],
  }) {
    for (final assignment in assignments) {
      if (assignment.formId == formTemplateId) return assignment.jobFormId;
    }
    for (final submission in submittedForms) {
      if (submission.formId == formTemplateId) return submission.jobFormId;
    }
    return null;
  }

  int? _resolveFormId(
    SubmittedJobForm submission,
    List<JobFormAssignment> assignments,
  ) {
    if (submission.formId != null) return submission.formId;
    for (final assignment in assignments) {
      if (assignment.jobFormId == submission.jobFormId) {
        return assignment.formId;
      }
    }
    return null;
  }

  Future<int> _resolveStoredJobFormId({
    required int jobId,
    required int formTemplateId,
    int? jobFormId,
    CachedJobFormSubmission? existing,
    List<JobFormAssignment> assignments = const [],
    bool allowRemoteLookup = true,
  }) async {
    if (jobFormId != null && jobFormId > 0) return jobFormId;
    if (existing != null && existing.jobFormId > 0) return existing.jobFormId;

    for (final assignment in assignments) {
      if (assignment.formId == formTemplateId && assignment.jobFormId > 0) {
        return assignment.jobFormId;
      }
    }

    final cachedJobFormId = await _database.readJobFormId(
      jobId: jobId,
      formId: formTemplateId,
    );
    if (cachedJobFormId != null && cachedJobFormId > 0) {
      return cachedJobFormId;
    }

    if (!allowRemoteLookup) {
      final links = await _database.listJobFormLinks(jobId);
      for (final link in links) {
        if (link.formId == formTemplateId && link.jobFormId > 0) {
          return link.jobFormId;
        }
      }
      if (links.length == 1) return links.first.jobFormId;
      return 0;
    }

    final resolved = await resolveJobFormId(
      jobId: jobId,
      formTemplateId: formTemplateId,
      assignments: assignments,
    );
    if (resolved != null && resolved > 0) return resolved;

    final links = await _database.listJobFormLinks(jobId);
    if (links.length == 1) return links.first.jobFormId;

    return 0;
  }

  Future<int?> _resolveSubmissionIdForForm({
    required int jobId,
    required int formTemplateId,
    CachedJobFormSubmission? local,
  }) async {
    final cachedId = local?.serverSubmissionId;
    if (cachedId != null && cachedId > 0) return cachedId;

    try {
      final linked = await _api.fetchJobLinkedForms(jobId);
      for (final row in linked) {
        if (row.formId == formTemplateId &&
            row.submissionId != null &&
            row.submissionId! > 0) {
          return row.submissionId;
        }
      }

      final submissions = await _api.fetchSubmittedJobForms(jobId);
      for (final row in submissions) {
        if (row.formId != formTemplateId) continue;
        final resolved = row.resolvedSubmissionId;
        if (resolved != null && resolved > 0) return resolved;
      }
    } on DioException catch (error) {
      if (!_isNetworkError(error) && !_isMissingSubmission(error)) rethrow;
    }

    return null;
  }

  bool _isMissingSubmission(DioException error) {
    final status = error.response?.statusCode;
    if (status == 404) return true;
    if (status != 400) return false;

    final data = error.response?.data;
    if (data == null) return true;
    final message = data.toString().toLowerCase();
    return message.contains('submission not found') ||
        message.contains('not found');
  }

  bool _isNetworkError(DioException error) {
    final type = error.type;
    return type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.unknown;
  }
}