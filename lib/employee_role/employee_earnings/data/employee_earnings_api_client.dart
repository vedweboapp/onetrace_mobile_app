import 'package:dio/dio.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/employee_role/employee_earnings/data/employee_earnings_models.dart';

final class EmployeeEarningsApiClient {
  EmployeeEarningsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<EmployeeEarningsListResponse> fetchEarnings({
    required int workerId,
    int page = 1,
    int pageSize = kDefaultApiPageSize,
  }) async {
    final query = <String, dynamic>{
      'worker': workerId,
      'page': page < 1 ? 1 : page,
      'page_size': pageSize,
    };

    final response = await _dio.get<dynamic>(
      AppApiUrls.jobEarnings,
      queryParameters: query,
    );
    final root = readApiMap(response.data);
    return EmployeeEarningsListResponse.fromMap(root);
  }
}
