import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/forms/data/form_models.dart';

/// HTTP client for `/api/v1/forms/` and nested rules/metadata/section routes.
final class FormsApiClient {
  FormsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static Options get _jsonWriteOptions => Options(
        headers: const <String, dynamic>{
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      );

  /// `GET /forms/` — [forms_list]
  Future<List<FormSummary>> fetchForms({
    int page = 1,
    int pageSize = 100,
  }) async {
    final out = <FormSummary>[];
    final seen = <int>{};
    var currentPage = page;

    while (true) {
      final response = await _dio.get<dynamic>(
        AppApiUrls.forms,
        queryParameters: <String, dynamic>{
          'page': currentPage,
          'page_size': pageSize,
        },
      );
      final root = readApiMap(response.data);
      final rows = readApiRows(root);
      for (final map in rows) {
        final form = FormSummary.fromJson(map);
        if (form.id <= 0 || !seen.add(form.id)) continue;
        out.add(form);
      }
      if (!readApiHasNextPage(root) || rows.isEmpty) break;
      currentPage += 1;
    }

    return out;
  }

  /// `GET /project-forms/?project_id=` — forms linked to a project.
  Future<List<FormSummary>> fetchProjectForms({
    required int projectId,
    int page = 1,
    int pageSize = 20,
    bool? isActive = true,
  }) async {
    final out = <FormSummary>[];
    final seen = <int>{};
    var currentPage = page;

    while (true) {
      final query = <String, dynamic>{
        'project_id': projectId,
        'page': currentPage,
        'page_size': pageSize,
      };
      if (isActive != null) query['is_active'] = isActive;

      final response = await _dio.get<dynamic>(
        AppApiUrls.projectForms,
        queryParameters: query,
      );
      final root = readApiMap(response.data);
      final rows = readApiRows(root);
      for (final map in rows) {
        final form = FormSummary.fromJson(map);
        if (form.id <= 0 || !seen.add(form.id)) continue;
        if (isActive == true && !form.isActive) continue;
        if (isActive == false && form.isActive) continue;
        out.add(form);
      }
      if (!readApiHasNextPage(root) || rows.isEmpty) break;
      currentPage += 1;
    }

    return out;
  }

  /// `GET /forms/{id}/` — [forms_read]
  Future<FormSummary> fetchFormById(String id) async {
    final response = await _dio.get<dynamic>(AppApiUrls.formById(id));
    final root = _coerceMap(response.data);
    final body = _entityBody(root);
    return FormSummary.fromJson(body);
  }

  /// `POST /forms/` — [forms_create]
  Future<FormSummary> createForm(Map<String, dynamic> payload) async {
    final response = await _dio.post<dynamic>(
      AppApiUrls.forms,
      data: payload,
      options: _jsonWriteOptions,
    );
    final root = _coerceMap(response.data);
    return FormSummary.fromJson(_entityBody(root));
  }

  /// `PUT /forms/{id}/` — [forms_update]
  Future<FormSummary> updateForm({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.put<dynamic>(
      AppApiUrls.formById(id),
      data: payload,
      options: _jsonWriteOptions,
    );
    final root = _coerceMap(response.data);
    return FormSummary.fromJson(_entityBody(root));
  }

  /// `PATCH /forms/{id}/` — [forms_partial_update]
  Future<FormSummary> patchForm({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.patch<dynamic>(
      AppApiUrls.formById(id),
      data: payload,
      options: _jsonWriteOptions,
    );
    final root = _coerceMap(response.data);
    return FormSummary.fromJson(_entityBody(root));
  }

  /// `DELETE /forms/{id}/` — [forms_delete]
  Future<void> deleteForm(String id) async {
    await _dio.delete<void>(AppApiUrls.formById(id));
  }

  /// `GET /forms/{id}/metadata/` — [forms_metadata]
  Future<Map<String, dynamic>> fetchFormMetadata(String id) async {
    final response = await _dio.get<dynamic>(AppApiUrls.formMetadataById(id));
    final root = _coerceMap(response.data);
    final body = _entityBody(root);
    return body.isNotEmpty ? body : root;
  }

  /// `GET /forms/{id}/rules/` — [forms_rules_read]
  Future<List<Map<String, dynamic>>> fetchFormRules(String formId) async {
    final response = await _dio.get<dynamic>(AppApiUrls.formRules(formId));
    final root = _coerceMap(response.data);
    return _readRows(root).map(_coerceMap).toList(growable: false);
  }

  /// `POST /forms/{id}/rules/` — [forms_rules_create]
  Future<Map<String, dynamic>> createFormRules({
    required String formId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post<dynamic>(
      AppApiUrls.formRules(formId),
      data: payload,
      options: _jsonWriteOptions,
    );
    return _entityBody(_coerceMap(response.data));
  }

  /// `PUT /forms/{id}/rules/` — [forms_rules_update]
  Future<Map<String, dynamic>> replaceFormRules({
    required String formId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.put<dynamic>(
      AppApiUrls.formRules(formId),
      data: payload,
      options: _jsonWriteOptions,
    );
    return _entityBody(_coerceMap(response.data));
  }

  /// `DELETE /forms/{id}/rules/` — [forms_rules_delete]
  Future<void> deleteFormRules(String formId) async {
    await _dio.delete<void>(AppApiUrls.formRules(formId));
  }

  /// `GET /forms/{id}/rules/{rule_id}/` — [forms_rules_read]
  Future<Map<String, dynamic>> fetchFormRuleById({
    required String formId,
    required String ruleId,
  }) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.formRuleById(formId, ruleId),
    );
    return _entityBody(_coerceMap(response.data));
  }

  /// `PUT /forms/{id}/rules/{rule_id}/` — [forms_rules_update]
  Future<Map<String, dynamic>> updateFormRule({
    required String formId,
    required String ruleId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.put<dynamic>(
      AppApiUrls.formRuleById(formId, ruleId),
      data: payload,
      options: _jsonWriteOptions,
    );
    return _entityBody(_coerceMap(response.data));
  }

  /// `DELETE /forms/{id}/rules/{rule_id}/` — [forms_rules_delete]
  Future<void> deleteFormRule({
    required String formId,
    required String ruleId,
  }) async {
    await _dio.delete<void>(AppApiUrls.formRuleById(formId, ruleId));
  }

  /// `POST /forms/{id}/section/` — add a section to a form.
  Future<Map<String, dynamic>> createFormSection({
    required String formId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post<dynamic>(
      AppApiUrls.formSections(formId),
      data: payload,
      options: _jsonWriteOptions,
    );
    return _entityBody(_coerceMap(response.data));
  }

  static Map<String, dynamic> _coerceMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _entityBody(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is Map) return _coerceMap(data);
    return root;
  }

  static List<dynamic> _readRows(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is List) return data;
    final results = root['results'];
    if (results is List) return results;
    return const [];
  }
}

final formsApiClientProvider = Provider<FormsApiClient>(
  (ref) => sl<FormsApiClient>(),
);
