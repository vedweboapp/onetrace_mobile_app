import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/database/technician_form_database.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/employee_role/forms/data/cached_technician_form.dart';
import 'package:red5/features/forms/data/forms_api_client.dart';

final technicianFormRepositoryProvider = Provider<TechnicianFormRepository>((ref) {
  return TechnicianFormRepository(
    formsApi: sl<FormsApiClient>(),
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
    required FormsApiClient formsApi,
    required TechnicianFormDatabase database,
    required ConnectivityService connectivity,
  })  : _formsApi = formsApi,
        _database = database,
        _connectivity = connectivity;

  final FormsApiClient _formsApi;
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
    final summary = await _formsApi.fetchFormById(id);
    final metadata = await _fetchMetadataOrEmpty(id);
    final rules = await _fetchRulesOrEmpty(id);

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

  Future<Map<String, dynamic>> _fetchMetadataOrEmpty(String id) async {
    try {
      return await _formsApi.fetchFormMetadata(id);
    } on DioException catch (error) {
      if (_isMissingOptionalResource(error)) return const {};
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRulesOrEmpty(String id) async {
    try {
      return await _formsApi.fetchFormRules(id);
    } on DioException catch (error) {
      if (_isMissingOptionalResource(error)) return const [];
      rethrow;
    }
  }

  Future<TechnicianFormBundle> _handleLoadFailure(int formId, Object error) async {
    final useCache = _shouldFallbackToCache(error);
    if (kDebugMode) {
      debugPrint(
        '[FORM-LOAD] formId=$formId | online=${_connectivity.isOnline} | '
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
