import 'package:dio/dio.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/employee_role/employee_earnings/data/employee_earnings_models.dart';

final class EmployeeEarningsApiClient {
  EmployeeEarningsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `GET /job-earnings/?worker=` — loads every page and merges `jobs`.
  Future<EmployeeEarningsListResponse> fetchEarnings({
    required int workerId,
    int pageSize = kDefaultApiPageSize,
  }) async {
    final firstRoot = await _getRaw(workerId: workerId, page: 1, pageSize: pageSize);
    final first = EmployeeEarningsListResponse.fromMap(firstRoot);
    final jobs = [...first.jobs];

    var page = 2;
    var hasNext = _hasNext(firstRoot);
    while (hasNext) {
      final root = await _getRaw(
        workerId: workerId,
        page: page,
        pageSize: pageSize,
      );
      final next = EmployeeEarningsListResponse.fromMap(root);
      if (next.jobs.isEmpty) break;
      jobs.addAll(next.jobs);
      hasNext = _hasNext(root);
      page++;
    }

    return EmployeeEarningsListResponse(summary: first.summary, jobs: jobs);
  }

  /// `POST /job-earnings/{id}/update-status/` — admin / manager mark paid.
  Future<void> updateEarningStatus({
    required int jobId,
    required String status,
    required List<int> pinIds,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      AppApiUrls.jobEarningsUpdateStatus(jobId),
      data: <String, dynamic>{
        'status': status,
        'pin_ids': pinIds,
      },
    );
  }

  Future<Map<String, dynamic>> _getRaw({
    required int workerId,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get<dynamic>(
      AppApiUrls.jobEarnings,
      queryParameters: <String, dynamic>{
        'worker': workerId,
        'page': page < 1 ? 1 : page,
        'page_size': pageSize,
      },
    );
    return readApiMap(response.data);
  }

  static bool _hasNext(Map<String, dynamic> root) {
    if (readApiHasNextPage(root)) return true;
    return readApiMap(root['pagination'])['next'] != null;
  }
}
