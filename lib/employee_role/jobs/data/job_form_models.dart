import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:red5/employee_role/forms/data/signature_form_value.dart';

/// `yyyy-MM-dd` wire format for date-only fields (no time).
bool isJobFormDateFieldType(String? fieldType) {
  if (isJobFormDateTimeFieldType(fieldType)) return false;
  switch (fieldType?.trim().toLowerCase()) {
    case 'date':
    case 'date_picker':
    case 'datepicker':
    case 'birth_date':
    case 'birthdate':
    case 'due_date':
      return true;
    default:
      return false;
  }
}

/// `yyyy-MM-ddTHH:mm` wire format for date & time fields.
bool isJobFormDateTimeFieldType(String? fieldType) {
  switch (fieldType?.trim().toLowerCase()) {
    case 'datetime':
    case 'date_time':
      return true;
    default:
      return false;
  }
}

bool isJobFormDateTimeWireValue(String raw) {
  return RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(raw.trim());
}

/// Dashed date-only values, e.g. `2026-06-25` or legacy `20260625`.
bool isJobFormDateWireValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  if (isJobFormDateTimeWireValue(trimmed)) return false;
  if (RegExp(r'^\d{8}$').hasMatch(trimmed)) return true;
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed);
}

String formatJobFormDateForApi(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatJobFormDateTimeForApi(DateTime date) {
  final datePart = formatJobFormDateForApi(date);
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '${datePart}T$h:$min';
}

/// Strips timestamp and normalizes to `yyyy-MM-dd` for date-only submit-form.
String normalizeJobFormDateValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) return trimmed;

  if (RegExp(r'^\d{8}$').hasMatch(trimmed)) {
    final year = int.parse(trimmed.substring(0, 4));
    final month = int.parse(trimmed.substring(4, 6));
    final day = int.parse(trimmed.substring(6, 8));
    return formatJobFormDateForApi(DateTime(year, month, day));
  }

  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) {
    return formatJobFormDateForApi(parsed);
  }

  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
  if (dateOnly != null) {
    final year = int.tryParse(dateOnly.group(1)!);
    final month = int.tryParse(dateOnly.group(2)!);
    final day = int.tryParse(dateOnly.group(3)!);
    if (year != null && month != null && day != null) {
      return formatJobFormDateForApi(DateTime(year, month, day));
    }
  }

  return trimmed;
}

/// Keeps time and normalizes to `yyyy-MM-ddTHH:mm` for datetime submit-form.
String normalizeJobFormDateTimeValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$').hasMatch(trimmed)) {
    return trimmed;
  }

  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) {
    return formatJobFormDateTimeForApi(parsed);
  }

  return trimmed;
}

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
  /// - `project_form_id` — project-job form template id (e.g. 18)
  /// - `dynamic_form_id` — service-job form template id (e.g. 34)
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
    this.localFilePath,
    this.fieldType,
  });

  final int fieldId;
  final String value;

  /// Local image/signature file uploaded as multipart `values[n][value]`.
  final String? localFilePath;

  /// Metadata `field_type` (e.g. `image_upload`, `signature`) for multipart submit.
  final String? fieldType;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'field_id': fieldId,
        'value': value,
      };

  Map<String, dynamic> toDbJson() => <String, dynamic>{
        ...toJson(),
        if (localFilePath != null && localFilePath!.trim().isNotEmpty)
          'local_file_path': localFilePath,
        if (fieldType != null && fieldType!.trim().isNotEmpty)
          'field_type': fieldType,
      };

  factory JobFormFieldValue.fromJson(Map<String, dynamic> map) {
    final fieldType = map['field_type']?.toString();
    var value = map['value']?.toString() ?? '';
    if (isJobFormDateFieldType(fieldType)) {
      value = normalizeJobFormDateValue(value);
    } else if (isJobFormDateTimeFieldType(fieldType) ||
        isJobFormDateTimeWireValue(value)) {
      value = normalizeJobFormDateTimeValue(value);
    } else if (isJobFormDateWireValue(value)) {
      value = normalizeJobFormDateValue(value);
    }
    return JobFormFieldValue(
      fieldId: _readInt(map['field_id']) ?? 0,
      value: value,
      localFilePath: map['local_file_path']?.toString(),
      fieldType: fieldType,
    );
  }
}

/// File-backed answers sent as multipart `values[n][field_id|field_type|value]`.
bool isJobFormAttachmentFieldType(String? fieldType) {
  switch (fieldType?.trim().toLowerCase()) {
    case 'image_upload':
    case 'image':
    case 'file':
    case 'file_upload':
    case 'signature':
    case 'digital_signature':
    case 'sign':
    case 'esign':
    case 'video_recorder':
    case 'video_recording':
    case 'video_record':
    case 'video':
    case 'video_upload':
      return true;
    default:
      return false;
  }
}

/// Scalar JSON rows vs file rows (website: scalars in `values`, files appended).
({List<JobFormFieldValue> scalars, List<JobFormFieldValue> attachments})
    splitJobFormValuesForSubmit(List<JobFormFieldValue> values) {
  final scalars = <JobFormFieldValue>[];
  final attachments = <JobFormFieldValue>[];
  for (final row in values) {
    final hasFile = row.localFilePath?.trim().isNotEmpty ?? false;
    if (isJobFormAttachmentFieldType(row.fieldType) || hasFile) {
      if (hasFile) attachments.add(row);
      continue;
    }
    scalars.add(row);
  }
  return (scalars: scalars, attachments: attachments);
}

@immutable
final class JobFormSubmitRequestParts {
  const JobFormSubmitRequestParts({
    required this.formFields,
    required this.attachments,
    required this.scalarValues,
  });

  final Map<String, dynamic> formFields;
  final List<JobFormFieldValue> attachments;
  final List<JobFormFieldValue> scalarValues;
}

JobFormSubmitRequestParts buildJobFormSubmitRequestParts({
  int? jobFormId,
  int? jobPinId,
  required String status,
  required List<JobFormFieldValue> values,
  String? remarks,
}) {
  final prepared = prepareJobFormValuesForApi(values);
  final split = splitJobFormValuesForSubmit(prepared);
  final preparedRemarks = prepareJobFormRemarksForApi(remarks);
  final linkField = jobPinId != null && jobPinId > 0
      ? <String, dynamic>{'job_pin_id': jobPinId}
      : <String, dynamic>{'job_form_id': jobFormId ?? 0};
  return JobFormSubmitRequestParts(
    scalarValues: split.scalars,
    attachments: split.attachments,
    formFields: <String, dynamic>{
      ...linkField,
      'status': status,
      if (preparedRemarks != null) 'remarks': preparedRemarks,
      'values': encodeJobFormValuesField(split.scalars),
    },
  );
}

JobFormSubmitRequestParts buildJobFormUpdateRequestParts({
  required String status,
  required List<JobFormFieldValue> values,
  String? remarks,
}) {
  final prepared = prepareJobFormValuesForApi(values);
  final split = splitJobFormValuesForSubmit(prepared);
  final preparedRemarks = prepareJobFormRemarksForApi(remarks);
  return JobFormSubmitRequestParts(
    scalarValues: split.scalars,
    attachments: split.attachments,
    formFields: <String, dynamic>{
      'status': status,
      if (preparedRemarks != null) 'remarks': preparedRemarks,
      'values': encodeJobFormValuesField(split.scalars),
    },
  );
}

@immutable
final class JobFormSubmitPayload {
  const JobFormSubmitPayload({
    required this.status,
    required this.values,
    this.jobFormId,
    this.jobPinId,
    this.remarks,
  });

  final int? jobFormId;
  final int? jobPinId;
  final String status;
  final String? remarks;
  final List<JobFormFieldValue> values;

  /// Wire body for `POST /jobs/{id}/submit-form/` (scalar `values` JSON string).
  Map<String, dynamic> toFormBody() =>
      buildJobFormSubmitRequestParts(
        jobFormId: jobFormId,
        jobPinId: jobPinId,
        status: status,
        values: values,
        remarks: remarks,
      ).formFields;

  Map<String, dynamic> toJson() => toFormBody();
}

/// Each stored answer is `varchar(100)` on the API (filename for signatures/images).
const int kJobFormApiValueMaxLength = 100;

/// API expects `values` as a JSON string (backend calls `json.loads` on it).
String encodeJobFormValuesField(List<JobFormFieldValue> values) {
  return jsonEncode(values.map((v) => v.toJson()).toList(growable: false));
}

List<JobFormFieldValue> prepareJobFormValuesForApi(
  List<JobFormFieldValue> values,
) {
  return values
      .map(_prepareJobFormValueRowForApi)
      .where(_shouldIncludeJobFormValueRow)
      .toList(growable: false);
}

JobFormFieldValue _prepareJobFormValueRowForApi(JobFormFieldValue row) {
  var value = row.value.trim();
  if (value.isEmpty) {
    value = _filenameFromLocalAttachmentPath(row.localFilePath);
  }
  return JobFormFieldValue(
    fieldId: row.fieldId,
    value: clampJobFormFieldValueForApi(
      value,
      fieldId: row.fieldId,
      fieldType: row.fieldType,
    ),
    localFilePath: row.localFilePath,
    fieldType: row.fieldType,
  );
}

bool _shouldIncludeJobFormValueRow(JobFormFieldValue row) {
  if (row.fieldId <= 0) return false;
  if (row.value.trim().isNotEmpty) return true;
  return row.localFilePath?.trim().isNotEmpty ?? false;
}

String _filenameFromLocalAttachmentPath(String? localFilePath) {
  final path = localFilePath?.trim();
  if (path == null || path.isEmpty) return '';
  final parts = path.split(RegExp(r'[\\/]'));
  return parts.isNotEmpty ? parts.last : '';
}

String? prepareJobFormRemarksForApi(String? remarks) {
  final trimmed = remarks?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return clampJobFormFieldValueForApi(trimmed);
}

String clampJobFormFieldValueForApi(
  String raw, {
  int fieldId = 0,
  String? fieldType,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (isJobFormDateFieldType(fieldType)) {
    return normalizeJobFormDateValue(trimmed);
  }
  if (isJobFormDateTimeFieldType(fieldType) ||
      isJobFormDateTimeWireValue(trimmed)) {
    return normalizeJobFormDateTimeValue(trimmed);
  }
  if (isJobFormDateWireValue(trimmed)) {
    return normalizeJobFormDateValue(trimmed);
  }
  if (isSignaturePngBase64Payload(trimmed)) {
    return fieldId > 0 ? signatureFilenameForField(fieldId) : 'signed';
  }
  if (isSignatureApiPayload(trimmed)) return trimmed;
  if (trimmed.length <= kJobFormApiValueMaxLength) return trimmed;

  if (trimmed.startsWith('{')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final name = decoded['name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          return _truncateJobFormApiValue(name);
        }
        if (decoded['signed'] == true) return 'signed';
      }
    } catch (_) {}
  }

  return _truncateJobFormApiValue(trimmed);
}

String _truncateJobFormApiValue(String value) {
  if (value.length <= kJobFormApiValueMaxLength) return value;
  return value.substring(0, kJobFormApiValueMaxLength);
}

List<JobFormFieldValue> decodeJobFormValuesField(dynamic raw) {
  if (raw == null) return const [];
  dynamic decoded = raw;
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    decoded = jsonDecode(trimmed);
  }
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map(
        (entry) => JobFormFieldValue.fromJson(
          Map<String, dynamic>.from(
            entry.map((k, v) => MapEntry(k.toString(), v)),
          ),
        ),
      )
      .toList(growable: false);
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

  Map<String, dynamic> toFormBody() =>
      buildJobFormUpdateRequestParts(
        status: status,
        values: values,
        remarks: remarks,
      ).formFields;

  Map<String, dynamic> toJson() => toFormBody();
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
    this.jobPinId,
    this.remarks,
    this.serverSubmissionId,
    this.lastError,
  });

  final String localId;
  final int jobId;
  final int formId;
  final int jobFormId;
  final int? jobPinId;
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
        if (jobPinId != null) 'job_pin_id': jobPinId,
        'status': status,
        'remarks': remarks,
        'values_json': jsonEncode(values.map((v) => v.toDbJson()).toList()),
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
      jobPinId: row['job_pin_id'] as int?,
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

  /// Parses `GET /jobs/{id}/` → `data.forms[]` for operative form picker display.
  static List<JobLinkedFormSummary> listFromJobRaw(Map<String, dynamic> raw) {
    for (final key in const [
      'forms',
      'job_forms',
      'linked_forms',
      'submitted_forms',
      'job_form_links',
    ]) {
      final parsed = _parseLinkedFormsList(raw[key]);
      if (parsed.isNotEmpty) return parsed;
    }

    final jobMeta = raw['job_meta'];
    if (jobMeta is Map) {
      final meta = Map<String, dynamic>.from(
        jobMeta.map((k, v) => MapEntry(k.toString(), v)),
      );
      for (final key in const ['forms', 'job_forms', 'linked_forms']) {
        final parsed = _parseLinkedFormsList(meta[key]);
        if (parsed.isNotEmpty) return parsed;
      }
    }

    return const [];
  }

  static List<JobLinkedFormSummary> _parseLinkedFormsList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <JobLinkedFormSummary>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(
        row.map((k, v) => MapEntry(k.toString(), v)),
      );
      final parsed = tryFromMap(map);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

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
        _readInt(map['dynamic_form_id']) ??
        _readInt(map['project_form_id']) ??
        _readInt(map['project_form']) ??
        _readInt(map['template_id']) ??
        _readInt(map['form_template_id']) ??
        (nestedMap != null ? _readInt(nestedMap['id']) : null);
    final hasExplicitFormId = map.containsKey('form_id') ||
        map.containsKey('dynamic_form_id') ||
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

    final isSubmittedFlag = map['is_submitted'] == true ||
        map['is_submitted']?.toString().toLowerCase() == 'true';
    final status = isSubmittedFlag
        ? 'submitted'
        : map['status']?.toString() ??
            map['submission_status']?.toString();

    return JobLinkedFormSummary(
      formId: formId,
      name: resolvedName,
      apiName: map['api_name']?.toString() ?? nestedMap?['api_name']?.toString(),
      jobFormId: jobFormId,
      submissionId: _readSubmissionId(map, formId: formId),
      status: status,
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
        _readInt(map['dynamic_form_id']) ??
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
  return decodeJobFormValuesField(valuesRaw);
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
        _readInt(map['dynamic_form_id']) ??
        _readInt(map['project_form_id']) ??
        _readInt(map['project_form']) ??
        _readInt(map['template_id']) ??
        _readInt(map['form_template_id']) ??
        (nestedMap != null ? _readInt(nestedMap['id']) : null) ??
        _readInt(nestedForm);
    final hasExplicitFormId = map.containsKey('form_id') ||
        map.containsKey('dynamic_form_id') ||
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
