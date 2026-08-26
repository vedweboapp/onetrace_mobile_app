import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';

/// HTTP client for material-requests, dispatch, and return-request APIs.
///
/// List filters follow the Greg pattern:
/// `?job=<jobId>&worker=<workerId>`
final class MaterialRequestsApiClient {
  MaterialRequestsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `GET /material-requests/?job=&worker=&status=`
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
        if (jobId != null && jobId > 0) 'job': jobId,
        if (workerId != null && workerId > 0) 'worker': workerId,
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

  /// Loads material requests for one worker across one or more jobs.
  ///
  /// Calls `GET /material-requests/?job=&worker=` per job id (Greg pattern).
  Future<List<MaterialRequestRead>> fetchMaterialRequestsForJobs({
    required int workerId,
    required List<int> jobIds,
    int? statusId,
  }) async {
    if (workerId <= 0) return const [];
    final uniqueJobIds = <int>{
      for (final id in jobIds)
        if (id > 0) id,
    };
    if (uniqueJobIds.isEmpty) {
      return fetchMaterialRequests(workerId: workerId, statusId: statusId);
    }

    final out = <MaterialRequestRead>[];
    final seen = <int>{};
    for (final jobId in uniqueJobIds) {
      final rows = await fetchMaterialRequests(
        workerId: workerId,
        jobId: jobId,
        statusId: statusId,
      );
      for (final row in rows) {
        if (seen.add(row.id)) out.add(row);
      }
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

  /// `GET /dispatch/?job=&worker=&material_request=`
  Future<List<MaterialDispatchRead>> fetchDispatches({
    int? workerId,
    int? jobId,
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
        if (jobId != null && jobId > 0) 'job': jobId,
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

  /// Operative Dispatch tab — prefer `?job=&worker=` (Greg), then narrow to MR.
  Future<List<MaterialDispatchRead>> fetchDispatchesForMaterialRequest({
    required int materialRequestId,
    int? workerId,
    List<int> jobIds = const [],
  }) async {
    Future<List<MaterialDispatchRead>> attempt({
      int? worker,
      int? job,
      int? materialRequest,
    }) async {
      try {
        return await fetchDispatches(
          workerId: worker,
          jobId: job,
          materialRequestId: materialRequest,
        );
      } catch (_) {
        return const [];
      }
    }

    final out = <MaterialDispatchRead>[];
    final seen = <int>{};

    void addScoped(List<MaterialDispatchRead> rows) {
      for (final row in rows) {
        if (row.materialRequestId != null &&
            row.materialRequestId != materialRequestId) {
          continue;
        }
        if (seen.add(row.id)) out.add(row);
      }
    }

    // Primary: /dispatch/?job=&worker= for each linked job.
    for (final jobId in jobIds) {
      if (jobId <= 0) continue;
      addScoped(await attempt(worker: workerId, job: jobId));
    }
    if (out.isNotEmpty) {
      final forMr = out
          .where((row) => row.materialRequestId == materialRequestId)
          .toList(growable: false);
      return forMr.isNotEmpty ? forMr : out;
    }

    // Fallback: material_request + worker.
    addScoped(
      await attempt(worker: workerId, materialRequest: materialRequestId),
    );
    if (out.isNotEmpty) return out;

    addScoped(await attempt(materialRequest: materialRequestId));
    return out;
  }

  /// `GET /return-request/?job=&worker=&material_request=`
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
        if (jobId != null && jobId > 0) 'job': jobId,
        if (workerId != null && workerId > 0) 'worker': workerId,
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

  /// Operative Return tab — prefer `?job=&worker=` (Greg), then narrow to MR.
  Future<List<MaterialReturnRequestRead>> fetchReturnRequestsForMaterialRequest({
    required int materialRequestId,
    int? workerId,
    List<int> jobIds = const [],
    Set<int> dispatchLineIds = const {},
  }) async {
    Future<List<MaterialReturnRequestRead>> attempt({
      int? worker,
      int? job,
      int? materialRequest,
    }) async {
      try {
        return await fetchReturnRequests(
          workerId: worker,
          jobId: job,
          materialRequestId: materialRequest,
        );
      } catch (_) {
        return const [];
      }
    }

    final out = <MaterialReturnRequestRead>[];
    final seen = <int>{};

    void addAll(List<MaterialReturnRequestRead> rows) {
      for (final row in rows) {
        if (seen.add(row.id)) out.add(row);
      }
    }

    List<MaterialReturnRequestRead> scoped(
      List<MaterialReturnRequestRead> rows,
    ) {
      if (rows.isEmpty) return rows;
      final byMr = rows
          .where((row) => row.materialRequestId == materialRequestId)
          .toList(growable: false);
      if (byMr.isNotEmpty) return byMr;
      if (dispatchLineIds.isEmpty) return rows;
      final byDispatch = rows
          .where(
            (row) => row.dispatchLineIds.any(dispatchLineIds.contains),
          )
          .toList(growable: false);
      return byDispatch.isNotEmpty ? byDispatch : rows;
    }

    // Primary: /return-request/?job=&worker= for each linked job.
    for (final jobId in jobIds) {
      if (jobId <= 0) continue;
      addAll(await attempt(worker: workerId, job: jobId));
    }
    if (out.isNotEmpty) return scoped(out);

    // Fallback: material_request + worker.
    addAll(
      await attempt(worker: workerId, materialRequest: materialRequestId),
    );
    if (out.isNotEmpty) return scoped(out);

    addAll(await attempt(materialRequest: materialRequestId));
    if (out.isNotEmpty) return scoped(out);

    if (workerId != null && workerId > 0) {
      addAll(await attempt(worker: workerId));
    }
    return scoped(out);
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
