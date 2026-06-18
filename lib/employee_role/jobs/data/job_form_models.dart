import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Link between a job and a form template (`job_form_id` for submit API).
@immutable
final class JobFormAssignment {
  const JobFormAssignment({
    required this.jobFormId,
    required this.formId,
    this.submissionId,
  });

  final int jobFormId;
  final int formId;

  /// Server submission row id from `GET /jobs/{id}/` forms[].submission_id.
  final int? submissionId;

  /// Parses `GET /jobs/{id}/` → `data.forms[]` where each row has:
  /// - `job_form_id` — sent in `POST .../submit-form/` (e.g. 14)
  /// - `project_form_id` — form template id / operative picker id (e.g. 18)
  static List<JobFormAssignment> listFromJobRaw(Map<String, dynamic> raw) {
    for (final key in const [
      'forms',
      'job_forms',
      'linked_forms',
      'submitted_forms',
      'job_form_links',
    ]) {
      final parsed = _parseFormsList(raw[key]);
      if (parsed.isNotEmpty) return parsed;
    }

    final jobMeta = raw['job_meta'];
    if (jobMeta is Map) {
      final meta = Map<String, dynamic>.from(
        jobMeta.map((k, v) => MapEntry(k.toString(), v)),
      );
      for (final key in const ['forms', 'job_forms', 'linked_forms']) {
        final parsed = _parseFormsList(meta[key]);
        if (parsed.isNotEmpty) return parsed;
      }
    }

    return const [];
  }

  static List<JobFormAssignment> fromLinkedForms(
    List<JobLinkedFormSummary> linked,
  ) {
    final out = <JobFormAssignment>[];
    for (final row in linked) {
      final jobFormId = row.jobFormId;
      if (jobFormId == null || jobFormId <= 0) continue;
      out.add(
        JobFormAssignment(
          jobFormId: jobFormId,
          formId: row.formId,
          submissionId: row.submissionId,
        ),
      );
    }
    return out;
  }

  static List<JobFormAssignment> mergeByFormId(
    Iterable<JobFormAssignment> base,
    Iterable<JobFormAssignment> overlay,
  ) {
    final merged = <int, JobFormAssignment>{
      for (final assignment in base) assignment.formId: assignment,
    };
    for (final assignment in overlay) {
      final existing = merged[assignment.formId];
      if (existing == null) {
        merged[assignment.formId] = assignment;
        continue;
      }
      merged[assignment.formId] = JobFormAssignment(
        jobFormId:
            assignment.jobFormId > 0 ? assignment.jobFormId : existing.jobFormId,
        formId: assignment.formId,
        submissionId: assignment.submissionId ?? existing.submissionId,
      );
    }
    return merged.values.toList(growable: false);
  }
}

@immutable
final class JobFormFieldValue {
  const JobFormFieldValue({
    required this.fieldId,
    required this.value,
  });

  final int fieldId;
  final String value;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'field_id': fieldId,
        'value': value,
      };

  factory JobFormFieldValue.fromJson(Map<String, dynamic> map) {
    return JobFormFieldValue(
      fieldId: _readInt(map['field_id']) ?? 0,
      value: map['value']?.toString() ?? '',
    );
  }
}

@immutable
final class JobFormSubmitPayload {
  const JobFormSubmitPayload({
    required this.jobFormId,
    required this.status,
    required this.values,
    this.remarks,
  });

  final int jobFormId;
  final String status;
  final String? remarks;
  final List<JobFormFieldValue> values;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'job_form_id': jobFormId,
        'status': status,
        if (remarks != null && remarks!.trim().isNotEmpty)
          'remarks': remarks!.trim(),
        'values': values.map((v) => v.toJson()).toList(growable: false),
      };
}

/// Body for `PUT /jobs/{jobId}/submitted-forms/{submissionId}/update/`.
@immutable
final class JobFormUpdatePayload {
  const JobFormUpdatePayload({
    required this.status,
    required this.values,
    this.remarks,
  });

  final String status;
  final String? remarks;
  final List<JobFormFieldValue> values;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status,
        if (remarks != null && remarks!.trim().isNotEmpty)
          'remarks': remarks!.trim(),
        'values': values.map((v) => v.toJson()).toList(growable: false),
      };
}

enum JobFormSubmissionSyncStatus { pending, synced, failed }

@immutable
final class CachedJobFormSubmission {
  const CachedJobFormSubmission({
    required this.localId,
    required this.jobId,
    required this.formId,
    required this.jobFormId,
    required this.status,
    required this.values,
    required this.syncStatus,
    required this.updatedAt,
    required this.createdAt,
    this.remarks,
    this.serverSubmissionId,
    this.lastError,
  });

  final String localId;
  final int jobId;
  final int formId;
  final int jobFormId;
  final String status;
  final String? remarks;
  final List<JobFormFieldValue> values;
  final JobFormSubmissionSyncStatus syncStatus;
  final int? serverSubmissionId;
  final String? lastError;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get isSubmitted => status == 'submitted';

  Map<String, dynamic> toDbRow() => <String, dynamic>{
        'local_id': localId,
        'job_id': jobId,
        'form_id': formId,
        'job_form_id': jobFormId,
        'status': status,
        'remarks': remarks,
        'values_json': jsonEncode(values.map((v) => v.toJson()).toList()),
        'sync_status': syncStatus.name,
        'server_submission_id': serverSubmissionId,
        'last_error': lastError,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static CachedJobFormSubmission fromDbRow(Map<String, dynamic> row) {
    final valuesRaw = jsonDecode(row['values_json'] as String);
    final values = valuesRaw is List
        ? valuesRaw
            .whereType<Map>()
            .map(
              (e) => JobFormFieldValue.fromJson(
                Map<String, dynamic>.from(
                  e.map((k, v) => MapEntry(k.toString(), v)),
                ),
              ),
            )
            .toList(growable: false)
        : const <JobFormFieldValue>[];

    return CachedJobFormSubmission(
      localId: row['local_id'] as String,
      jobId: row['job_id'] as int,
      formId: row['form_id'] as int,
      jobFormId: row['job_form_id'] as int,
      status: row['status'] as String? ?? 'submitted',
      remarks: row['remarks'] as String?,
      values: values,
      syncStatus: _parseSyncStatus(row['sync_status'] as String?),
      serverSubmissionId: row['server_submission_id'] as int?,
      lastError: row['last_error'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }
}

/// Form linked to a job from `GET /jobs/{jobId}/submitted-forms/`.
///
/// Path uses the operative [jobId]; each item's [formId] is the form template id
/// (`id` in the API body), not the job id.
@immutable
final class JobLinkedFormSummary {
  const JobLinkedFormSummary({
    required this.formId,
    required this.name,
    this.apiName,
    this.jobFormId,
    this.submissionId,
    this.status,
  });

  final int formId;
  final String name;
  final String? apiName;
  final int? jobFormId;

  /// Server submission row id for `PUT .../submitted-forms/{id}/update/`.
  final int? submissionId;
  final String? status;

  bool get isSubmitted => status?.trim().toLowerCase() == 'submitted';

  static JobLinkedFormSummary? tryFromMap(Map<String, dynamic> map) {
    final nestedForm = map['form'];
    final nestedMap = nestedForm is Map
        ? Map<String, dynamic>.from(
            nestedForm.map((k, v) => MapEntry(k.toString(), v)),
          )
        : null;

    final rowId = _readInt(map['id']);
    var jobFormId = _readInt(map['job_form_id']) ?? _readInt(map['job_form']);
    var formId = _readInt(map['form_id']) ??
        _readInt(map['project_form_id']) ??
        _readInt(map['project_form']) ??
        _readInt(map['template_id']) ??
        _readInt(map['form_template_id']) ??
        (nestedMap != null ? _readInt(nestedMap['id']) : null);
    final hasExplicitFormId = map.containsKey('form_id') ||
        map.containsKey('project_form_id') ||
        map.containsKey('project_form') ||
        map.containsKey('template_id') ||
        map.containsKey('form_template_id') ||
        nestedMap != null;

    if (formId == null && rowId != null) {
      formId = rowId;
    }
    if (jobFormId == null &&
        rowId != null &&
        formId != null &&
        (hasExplicitFormId || rowId != formId)) {
      jobFormId = rowId;
    }
    if (formId == null) return null;

    final name =
        map['name']?.toString().trim() ??
        nestedMap?['name']?.toString().trim() ??
        '';
    final resolvedName = name.isNotEmpty ? name : 'Form $formId';

    return JobLinkedFormSummary(
      formId: formId,
      name: resolvedName,
      apiName: map['api_name']?.toString() ?? nestedMap?['api_name']?.toString(),
      jobFormId: jobFormId,
      submissionId: _readSubmissionId(map, formId: formId),
      status: map['status']?.toString(),
    );
  }
}

@immutable
final class SubmittedJobForm {
  const SubmittedJobForm({
    required this.id,
    required this.jobFormId,
    required this.status,
    required this.values,
    this.formId,
    this.submissionId,
    this.remarks,
  });

  final int id;
  final int jobFormId;
  final int? formId;

  /// Distinct submission row id when list `id` is the form template id.
  final int? submissionId;
  final String status;
  final String? remarks;
  final List<JobFormFieldValue> values;

  int? get resolvedSubmissionId {
    if (submissionId != null && submissionId! > 0) return submissionId;
    if (values.isEmpty && status.trim().isEmpty) return null;
    if (formId != null && id != formId) return id;
    return id > 0 ? id : null;
  }

  bool get isSubmitted =>
      status.trim().toLowerCase() == 'submitted';

  static SubmittedJobForm? tryFromMap(Map<String, dynamic> map) {
    if (JobLinkedFormSummary.tryFromMap(map) != null &&
        map['values'] == null &&
        map['job_form_id'] == null &&
        map['job_form'] == null &&
        map['status'] == null) {
      return null;
    }

    final nestedForm = map['form'];
    final nestedMap = nestedForm is Map
        ? Map<String, dynamic>.from(
            nestedForm.map((k, v) => MapEntry(k.toString(), v)),
          )
        : null;

    final formId =
        _readInt(map['form_id']) ??
        _readInt(map['project_form_id']) ??
        (nestedMap != null ? _readInt(nestedMap['id']) : null);

    final jobFormId =
        _readInt(map['job_form_id']) ?? _readInt(map['job_form']);

    final values = _parseFieldValues(map['values']);
    final status = map['status']?.toString();
    final id = _readInt(map['id']) ?? formId;
    final submissionId = _readSubmissionId(map, formId: formId);

    if (id == null) return null;
    if (jobFormId == null && values.isEmpty && status == null) return null;

    return SubmittedJobForm(
      id: id,
      jobFormId: jobFormId ?? id,
      formId: formId ?? id,
      submissionId: submissionId,
      status: status ?? 'submitted',
      remarks: map['remarks']?.toString(),
      values: values,
    );
  }
}

int? _readSubmissionId(Map<String, dynamic> map, {int? formId}) {
  for (final key in const [
    'submission_id',
    'submitted_form_id',
    'form_submission_id',
  ]) {
    final parsed = _readInt(map[key]);
    if (parsed != null && parsed > 0) return parsed;
  }

  final rawId = _readInt(map['id']);
  if (rawId != null && formId != null && rawId != formId) return rawId;
  if (rawId != null && _parseFieldValues(map['values']).isNotEmpty) {
    return rawId;
  }
  if (rawId != null && map['status']?.toString().trim().isNotEmpty == true) {
    return rawId;
  }
  return null;
}

List<JobFormFieldValue> _parseFieldValues(dynamic valuesRaw) {
  final values = <JobFormFieldValue>[];
  if (valuesRaw is! List) return values;
  for (final entry in valuesRaw) {
    if (entry is! Map) continue;
    values.add(
      JobFormFieldValue.fromJson(
        Map<String, dynamic>.from(
          entry.map((k, v) => MapEntry(k.toString(), v)),
        ),
      ),
    );
  }
  return values;
}

List<JobFormAssignment> _parseFormsList(dynamic raw) {
  if (raw is! List) return const [];
  final out = <JobFormAssignment>[];
  for (final row in raw) {
    if (row is! Map) continue;
    final map = Map<String, dynamic>.from(
      row.map((k, v) => MapEntry(k.toString(), v)),
    );
    final nestedForm = map['form'];
    final nestedMap = nestedForm is Map
        ? Map<String, dynamic>.from(
            nestedForm.map((k, v) => MapEntry(k.toString(), v)),
          )
        : null;

    final rowId = _readInt(map['id']);
    var jobFormId = _readInt(map['job_form_id']) ?? _readInt(map['job_form']);
    var formId = _readInt(map['form_id']) ??
        _readInt(map['project_form_id']) ??
        _readInt(map['project_form']) ??
        _readInt(map['template_id']) ??
        _readInt(map['form_template_id']) ??
        (nestedMap != null ? _readInt(nestedMap['id']) : null) ??
        _readInt(nestedForm);
    final hasExplicitFormId = map.containsKey('form_id') ||
        map.containsKey('project_form_id') ||
        map.containsKey('project_form') ||
        map.containsKey('template_id') ||
        map.containsKey('form_template_id') ||
        nestedMap != null;

    if (formId == null && rowId != null) {
      formId = rowId;
    }
    if (jobFormId == null &&
        rowId != null &&
        formId != null &&
        (hasExplicitFormId || rowId != formId)) {
      jobFormId = rowId;
    }
    if (jobFormId == null || formId == null) continue;
    out.add(
      JobFormAssignment(
        jobFormId: jobFormId,
        formId: formId,
        submissionId: _readInt(map['submission_id']),
      ),
    );
  }
  return out;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

JobFormSubmissionSyncStatus _parseSyncStatus(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'synced':
      return JobFormSubmissionSyncStatus.synced;
    case 'failed':
      return JobFormSubmissionSyncStatus.failed;
    default:
      return JobFormSubmissionSyncStatus.pending;
  }
}
