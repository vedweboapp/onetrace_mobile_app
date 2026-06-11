import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/database/technician_form_database.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/employee_role/forms/data/cached_technician_form.dart';
import 'package:red5/features/forms/data/form_models.dart';
import 'package:red5/features/forms/data/forms_api_client.dart';

final technicianFormRepositoryProvider = Provider<TechnicianFormRepository>((ref) {
  return TechnicianFormRepository(
    formsApi: sl<FormsApiClient>(),
    database: sl<TechnicianFormDatabase>(),
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
  })  : _formsApi = formsApi,
        _database = database;

  final FormsApiClient _formsApi;
  final TechnicianFormDatabase _database;

  Future<TechnicianFormBundle> loadForm(int formId) async {
    try {
      return await _fetchFromApiAndCache(formId);
    } on DioException {
      return _readCacheOrThrow(formId);
    } catch (error) {
      if (_isLikelyNetworkError(error)) {
        return _readCacheOrThrow(formId);
      }
      rethrow;
    }
  }

  Future<TechnicianFormBundle> refreshForm(int formId) async {
    try {
      return await _fetchFromApiAndCache(formId);
    } on DioException {
      return _readCacheOrThrow(formId);
    } catch (error) {
      if (_isLikelyNetworkError(error)) {
        return _readCacheOrThrow(formId);
      }
      rethrow;
    }
  }

  Future<List<int>> watchCachedFormIds() => _database.listCachedFormIds();

  Future<TechnicianFormBundle> _fetchFromApiAndCache(int formId) async {
    final id = formId.toString();
    final results = await Future.wait<dynamic>([
      _formsApi.fetchFormById(id),
      _formsApi.fetchFormMetadata(id),
      _formsApi.fetchFormRules(id),
    ]);

    final summary = results[0] as FormSummary;
    final metadata = results[1] as Map<String, dynamic>;
    final rules = results[2] as List<Map<String, dynamic>>;
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

  Future<TechnicianFormBundle> _readCacheOrThrow(int formId) async {
    final cached = await _database.readForm(formId);
    if (cached == null) {
      throw TechnicianFormLoadException(
        'Form is not available offline. Connect to the internet and try again.',
      );
    }
    return cached.copyWith(source: TechnicianFormSource.cache);
  }

  bool _isLikelyNetworkError(Object error) {
    if (error is DioException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection');
  }
}
