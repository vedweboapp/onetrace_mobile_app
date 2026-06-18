import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/utils/qr_code_utils.dart';
import 'package:red5/employee_role/jobs/data/job_completion_debug_log.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';

final employeeJobFormsApiClientProvider = Provider<EmployeeJobFormsApiClient>(
  (ref) => sl<EmployeeJobFormsApiClient>(),
);

final class EmployeeJobFormsApiClient {
  EmployeeJobFormsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _jobIdHeader = 'X-Job-Id';

  Options _jobOptions(int jobId) => Options(
        headers: <String, String>{
          _jobIdHeader: jobId.toString(),
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      );

  /// `POST /jobs/{jobId}/submit-form/` — [jobId] is the operative's job, not the form template id.
  Future<SubmittedJobForm> submitJobForm({
    required int jobId,
    required JobFormSubmitPayload payload,
  }) async {
    final url = AppApiUrls.jobSubmitForm(jobId);
    final requestBody = payload.toJson();

    final response = await _dio.post<dynamic>(
      url,
      data: requestBody,
      options: _jobOptions(jobId),
    );

    JobCompletionDebugLog.formApi(
      label: 'POST submit-form',
      method: 'POST',
      url: '/api/v1$url',
      request: requestBody,
      statusCode: response.statusCode,
      response: response.data,
    );

    final body = _entityBody(_coerceMap(response.data));
    final parsed = SubmittedJobForm.tryFromMap(body);
    if (parsed != null) return parsed;

    final submissionId = _readInt(body['submission_id']) ??
        _readInt(body['submitted_form_id']) ??
        _readInt(body['id']);
    return SubmittedJobForm(
      id: submissionId ?? 0,
      submissionId: submissionId,
      jobFormId: payload.jobFormId,
      formId: _readInt(body['form_id']),
      status: body['status']?.toString() ?? payload.status,
      remarks: body['remarks']?.toString() ?? payload.remarks,
      values: payload.values,
    );
  }

  /// `GET /jobs/{jobId}/submitted-forms/` — [jobId] is the operative job, not form id.
  ///
  /// Returns form-template rows (`id` = form template id). Submission rows include
  /// `status`, `values`, and/or `job_form_id`.
  Future<List<JobLinkedFormSummary>> fetchJobLinkedForms(int jobId) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.jobSubmittedForms(jobId),
      options: _jobOptions(jobId),
    );
    return _parseJobLinkedFormsList(response.data);
  }

  Future<List<SubmittedJobForm>> fetchSubmittedJobForms(int jobId) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.jobSubmittedForms(jobId),
      options: _jobOptions(jobId),
    );
    return _parseSubmittedFormsList(response.data);
  }

  /// `POST /jobs/{id}/scan-qr/` — body `{ "qr_code": "QR-10001" }`.
  Future<void> scanJobQr({
    required int jobId,
    required String qrCode,
  }) async {
    final normalized = QrCodeUtils.normalizeScannedValue(qrCode);
    await _dio.post<dynamic>(
      AppApiUrls.jobScanQr(jobId),
      data: <String, dynamic>{'qr_code': normalized},
      options: Options(
        headers: <String, String>{
          _jobIdHeader: jobId.toString(),
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
  }

  /// `PUT /jobs/{jobId}/submitted-forms/{submissionId}/update/`
  Future<SubmittedJobForm> updateSubmittedJobForm({
    required int jobId,
    required int submissionId,
    required JobFormUpdatePayload payload,
  }) async {
    final url = AppApiUrls.jobSubmittedFormUpdate(jobId, submissionId);
    final requestBody = payload.toJson();

    final response = await _dio.put<dynamic>(
      url,
      data: requestBody,
      options: _jobOptions(jobId),
    );

    JobCompletionDebugLog.formApi(
      label: 'PUT update submitted form',
      method: 'PUT',
      url: '/api/v1$url',
      request: requestBody,
      statusCode: response.statusCode,
      response: response.data,
    );

    final body = _entityBody(_coerceMap(response.data));
    final parsed = SubmittedJobForm.tryFromMap(body);
    if (parsed != null) return parsed;

    return SubmittedJobForm(
      id: submissionId,
      submissionId: submissionId,
      jobFormId: submissionId,
      formId: _readInt(body['form_id']),
      status: payload.status,
      remarks: payload.remarks,
      values: payload.values,
    );
  }

  /// `GET /jobs/{jobId}/submitted-forms/{submissionId}/`
  Future<SubmittedJobForm> fetchSubmittedJobForm({
    required int jobId,
    required int submissionId,
  }) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.jobSubmittedFormById(jobId, submissionId),
      options: _jobOptions(jobId),
    );
    final body = _entityBody(_coerceMap(response.data));
    final parsed = SubmittedJobForm.tryFromMap(body);
    if (parsed == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Submitted form response missing id.',
      );
    }
    return parsed;
  }

  List<JobLinkedFormSummary> _parseJobLinkedFormsList(dynamic data) {
    final root = _coerceMap(data);
    final listRaw = root['data'] ?? root['results'] ?? root['items'] ?? data;
    if (listRaw is! List) {
      final single = JobLinkedFormSummary.tryFromMap(root);
      return single == null ? const [] : [single];
    }

    final out = <JobLinkedFormSummary>[];
    for (final row in listRaw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(
        row.map((k, v) => MapEntry(k.toString(), v)),
      );
      final parsed = JobLinkedFormSummary.tryFromMap(map);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  List<SubmittedJobForm> _parseSubmittedFormsList(dynamic data) {
    final root = _coerceMap(data);
    final listRaw = root['data'] ?? root['results'] ?? root['items'] ?? data;
    if (listRaw is! List) {
      final single = SubmittedJobForm.tryFromMap(root);
      return single == null ? const [] : [single];
    }

    final out = <SubmittedJobForm>[];
    for (final row in listRaw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(
        row.map((k, v) => MapEntry(k.toString(), v)),
      );
      final parsed = SubmittedJobForm.tryFromMap(map);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  static Map<String, dynamic> _coerceMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _entityBody(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    final result = root['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(
        result.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return root;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }
}
