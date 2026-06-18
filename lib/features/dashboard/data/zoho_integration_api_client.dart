import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/dashboard/data/zoho_integration_models.dart';

final class ZohoIntegrationApiClient {
  ZohoIntegrationApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `POST/GET /integrations/zoho/connect/` — returns OAuth `authorization_url`.
  Future<ZohoConnectResult> connect() async {
    Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(AppApiUrls.zohoConnect);
    } on DioException catch (e) {
      if (e.response?.statusCode == 405) {
        response = await _dio.get<Map<String, dynamic>>(AppApiUrls.zohoConnect);
      } else {
        rethrow;
      }
    }
    final body = _readBody(response.data);
    final result = ZohoConnectResult.fromJson(body);
    if (result.connectionId <= 0 || result.authorizationUrl.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message:
            'Zoho connect response missing connection_id or authorization_url.',
      );
    }
    return result;
  }

  Map<String, dynamic> _readBody(Map<String, dynamic>? raw) {
    if (raw == null) return const <String, dynamic>{};
    return readApiEntityBody(raw);
  }
}

final zohoIntegrationApiClientProvider = Provider<ZohoIntegrationApiClient>(
  (ref) => sl<ZohoIntegrationApiClient>(),
);
