import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';

/// HTTP client for material-requests, dispatch, and return-request APIs.
final class MaterialRequestsApiClient {
  MaterialRequestsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `GET /material-requests/?worker=&job=&status=`
  Future<List<MaterialRequestRead>> fetchMaterialRequests({
    int? workerId,
    int? jobId,
    int? statusId,
    int page = 1,
    int pageSize = 20,
    bool fetchAllPages = true,
  }) async {
    final out = <MaterialRequestRead>[];
    final seen = <int>{};
    var currentPage = page < 1 ? 1 : page;

    while (true) {
      final query = <String, dynamic>{
        'page': currentPage,
        'page_size': pageSize,
        if (workerId != null && workerId > 0) 'worker': workerId,
        if (jobId != null && jobId > 0) 'job': jobId,
        if (statusId != null && statusId > 0) 'status': statusId,
      };

      final response = await _dio.get<dynamic>(
        AppApiUrls.materialRequests,
        queryParameters: query,
      );
      final root = readApiMap(response.data);
      final rows = readApiRows(root);
      for (final map in rows) {
        final parsed = MaterialRequestRead.tryFromMap(map);
        if (parsed == null || !seen.add(parsed.id)) continue;
        out.add(parsed);
      }

      if (!fetchAllPages || !readApiHasNextPage(root) || rows.isEmpty) {
        break;
      }
      currentPage += 1;
    }

    return out;
  }

  /// `GET /material-requests/{id}/`
  Future<MaterialRequestRead> fetchMaterialRequestById(String id) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.materialRequestById(id),
    );
    final root = readApiMap(response.data);
    final body = _entityBody(root);
    final parsed = MaterialRequestRead.tryFromMap(body);
    if (parsed == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Material request response is invalid.',
      );
    }
    return parsed;
  }

  /// `GET /dispatch/?worker=&material_request=`
  ///
  /// Dispatch model fields are `worker` / `material_request` (not `job` /
  /// `job_worker`).
  Future<List<MaterialDispatchRead>> fetchDispatches({
    int? workerId,
    int? materialRequestId,
    int page = 1,
    int pageSize = 20,
    bool fetchAllPages = true,
  }) async {
    final out = <MaterialDispatchRead>[];
    final seen = <int>{};
    var currentPage = page < 1 ? 1 : page;

    while (true) {
      final query = <String, dynamic>{
        'page': currentPage,
        'page_size': pageSize,
        if (workerId != null && workerId > 0) 'worker': workerId,
        if (materialRequestId != null && materialRequestId > 0)
          'material_request': materialRequestId,
      };
      final response = await _dio.get<dynamic>(
        AppApiUrls.dispatches,
        queryParameters: query,
      );
      final root = readApiMap(response.data);
      final rows = readApiRows(root);
      for (final map in rows) {
        final parsed = MaterialDispatchRead.tryFromMap(map);
        if (parsed == null || !seen.add(parsed.id)) continue;
        out.add(parsed);
      }
      if (!fetchAllPages || !readApiHasNextPage(root) || rows.isEmpty) {
        break;
      }
      currentPage += 1;
    }

    return out;
  }

  /// `GET /return-request/?job=&worker=`
  ///
  /// Uses `worker` (not `job_worker`).
  Future<List<MaterialReturnRequestRead>> fetchReturnRequests({
    int? workerId,
    int? jobId,
    int? materialRequestId,
    int page = 1,
    int pageSize = 20,
    bool fetchAllPages = true,
  }) async {
    final out = <MaterialReturnRequestRead>[];
    final seen = <int>{};
    var currentPage = page < 1 ? 1 : page;

    while (true) {
      final query = <String, dynamic>{
        'page': currentPage,
        'page_size': pageSize,
        if (workerId != null && workerId > 0) 'worker': workerId,
        if (jobId != null && jobId > 0) 'job': jobId,
        if (materialRequestId != null && materialRequestId > 0)
          'material_request': materialRequestId,
      };
      final response = await _dio.get<dynamic>(
        AppApiUrls.returnRequests,
        queryParameters: query,
      );
      final root = readApiMap(response.data);
      final rows = readApiRows(root);
      for (final map in rows) {
        final parsed = MaterialReturnRequestRead.tryFromMap(map);
        if (parsed == null || !seen.add(parsed.id)) continue;
        out.add(parsed);
      }
      if (!fetchAllPages || !readApiHasNextPage(root) || rows.isEmpty) {
        break;
      }
      currentPage += 1;
    }

    return out;
  }

  /// `GET /dispatch/{id}/`
  Future<MaterialDispatchRead> fetchDispatchById(String id) async {
    final response = await _dio.get<dynamic>(AppApiUrls.dispatchById(id));
    final root = readApiMap(response.data);
    final body = _entityBody(root);
    final parsed = MaterialDispatchRead.tryFromMap(body);
    if (parsed == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Dispatch response is invalid.',
      );
    }
    return parsed;
  }

  /// `GET /return-request/{id}/`
  Future<MaterialReturnRequestRead> fetchReturnRequestById(String id) async {
    final response = await _dio.get<dynamic>(AppApiUrls.returnRequestById(id));
    final root = readApiMap(response.data);
    final body = _entityBody(root);
    final parsed = MaterialReturnRequestRead.tryFromMap(body);
    if (parsed == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Return request response is invalid.',
      );
    }
    return parsed;
  }

  static Map<String, dynamic> _entityBody(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return root;
  }
}

final materialRequestsApiClientProvider = Provider<MaterialRequestsApiClient>(
  (ref) => sl<MaterialRequestsApiClient>(),
);
