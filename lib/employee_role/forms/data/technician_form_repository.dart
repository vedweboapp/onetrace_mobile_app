import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/database/technician_form_database.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/employee_role/forms/data/cached_technician_form.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';
import 'package:red5/employee_role/forms/data/operative_project_forms_api_client.dart';
import 'package:red5/features/forms/data/form_models.dart';

final technicianFormRepositoryProvider = Provider<TechnicianFormRepository>((ref) {
  return TechnicianFormRepository(
    projectFormsApi: sl<OperativeProjectFormsApiClient>(),
    database: sl<TechnicianFormDatabase>(),
    connectivity: sl<ConnectivityService>(),
  );
});

final class TechnicianFormLoadException implements Exception {
  TechnicianFormLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class TechnicianFormRepository {
  TechnicianFormRepository({
    required OperativeProjectFormsApiClient projectFormsApi,
    required TechnicianFormDatabase database,
    required ConnectivityService connectivity,
  })  : _projectFormsApi = projectFormsApi,
        _database = database,
        _connectivity = connectivity;

  final OperativeProjectFormsApiClient _projectFormsApi;
  final TechnicianFormDatabase _database;
  final ConnectivityService _connectivity;

  Future<TechnicianFormBundle> loadForm(int formId) async {
    try {
      return await _fetchFromApiAndCache(formId);
    } on TechnicianFormLoadException {
      rethrow;
    } on DioException catch (error) {
      return _handleLoadFailure(formId, error);
    } catch (error) {
      if (_isTransientNetworkError(error)) {
        return _handleLoadFailure(formId, error);
      }
      throw TechnicianFormLoadException(
        ApiResponseMessage.fromAnyError(
          error,
          genericFallback: 'Unable to load form.',
        ),
      );
    }
  }

  Future<TechnicianFormBundle> refreshForm(int formId) async {
    return loadForm(formId);
  }

  Future<List<int>> watchCachedFormIds() => _database.listCachedFormIds();

  Future<TechnicianFormBundle> _fetchFromApiAndCache(int formId) async {
    final id = formId.toString();
    final metadata = await _projectFormsApi.fetchProjectFormMetadata(id);
    final summary = await _fetchSummary(id, formId, metadata);
    var rules = parseFormMetadataRules(metadata);
    if (rules.isEmpty) {
      rules = await _fetchRulesOrEmpty(id);
    }

    final contentHash = TechnicianFormBundle.computeContentHash(
      summaryRaw: summary.raw,
      metadata: metadata,
      rules: rules,
    );
    final bundle = TechnicianFormBundle(
      formId: formId,
      summary: summary,
      metadata: metadata,
      rules: rules,
      fetchedAt: DateTime.now(),
      source: TechnicianFormSource.remote,
      contentHash: contentHash,
    );
    await _database.upsertForm(bundle);
    return bundle;
  }

  Future<FormSummary> _fetchSummary(
    String id,
    int formId,
    Map<String, dynamic> metadata,
  ) async {
    try {
      return await _projectFormsApi.fetchProjectFormById(id);
    } on DioException catch (error) {
      if (!_isMissingOptionalResource(error)) rethrow;
      return _summaryFromMetadata(formId, metadata);
    }
  }

  FormSummary _summaryFromMetadata(int formId, Map<String, dynamic> metadata) {
    final name = metadata['name']?.toString().trim() ??
        metadata['form_name']?.toString().trim() ??
        metadata['title']?.toString().trim();
    return FormSummary.fromJson(<String, dynamic>{
      ...metadata,
      'id': formId,
      if (name != null && name.isNotEmpty) 'name': name,
    });
  }

  Future<List<Map<String, dynamic>>> _fetchRulesOrEmpty(String id) async {
    try {
      return await _projectFormsApi.fetchProjectFormRules(id);
    } on DioException catch (error) {
      if (_isMissingOptionalResource(error)) return const [];
      rethrow;
    }
  }

  Future<TechnicianFormBundle> _handleLoadFailure(int formId, Object error) async {
    final useCache = _shouldFallbackToCache(error);
    if (kDebugMode) {
      debugPrint(
        '[FORM-LOAD] project_form_id=$formId | online=${_connectivity.isOnline} | '
        'useCache=$useCache | error=$error',
      );
    }

    if (useCache) {
      final cached = await _database.readForm(formId);
      if (cached != null) {
        return cached.copyWith(source: TechnicianFormSource.cache);
      }
    }

    if (!_connectivity.isOnline || _isTransientNetworkError(error)) {
      throw TechnicianFormLoadException(
        'Form is not available offline. Connect to the internet and try again.',
      );
    }

    throw TechnicianFormLoadException(
      ApiResponseMessage.fromAnyError(
        error,
        genericFallback: 'Unable to load form $formId. Tap Retry.',
      ),
    );
  }

  bool _shouldFallbackToCache(Object error) {
    if (!_connectivity.isOnline) return true;
    return _isTransientNetworkError(error);
  }

  bool _isMissingOptionalResource(DioException error) {
    final status = error.response?.statusCode;
    return status == 404 || status == 405;
  }

  bool _isTransientNetworkError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          return true;
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          return status == null || status >= 500;
        default:
          return false;
      }
    }
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection');
  }
}
