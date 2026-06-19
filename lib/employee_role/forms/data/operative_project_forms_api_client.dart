import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/forms/data/form_models.dart';

/// Operative-side HTTP client for `/api/v1/project-forms/`.
final class OperativeProjectFormsApiClient {
  OperativeProjectFormsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `GET /project-forms/{id}/metadata/` — layout sections + fields.
  Future<Map<String, dynamic>> fetchProjectFormMetadata(String id) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.projectFormMetadataById(id),
    );
    final root = _coerceMap(response.data);
    final body = _entityBody(root);
    return body.isNotEmpty ? body : root;
  }

  /// `GET /project-forms/{id}/` — optional summary when metadata omits name.
  Future<FormSummary> fetchProjectFormById(String id) async {
    final response = await _dio.get<dynamic>(AppApiUrls.projectFormById(id));
    final root = _coerceMap(response.data);
    final body = _entityBody(root);
    return FormSummary.fromJson(body);
  }

  /// `GET /project-forms/{id}/rules/`
  Future<List<Map<String, dynamic>>> fetchProjectFormRules(String formId) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.projectFormRules(formId),
    );
    final root = _coerceMap(response.data);
    return _readRows(root).map(_coerceMap).toList(growable: false);
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

  static List<dynamic> _readRows(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is List) return data;
    final results = root['results'];
    if (results is List) return results;
    return const [];
  }
}

final operativeProjectFormsApiClientProvider =
    Provider<OperativeProjectFormsApiClient>(
  (ref) => sl<OperativeProjectFormsApiClient>(),
);
