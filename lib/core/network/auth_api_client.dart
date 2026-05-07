import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_urls.dart';

/// Auth endpoints using Dio ([AppApiUrls] for paths).
final class AuthApiClient {
  AuthApiClient({Dio? dio}) : _dio = dio ?? _createDefaultDio();

  final Dio _dio;

  static Dio _createDefaultDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppApiUrls.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    dio.interceptors.add(ApiDioLogInterceptor());
    return dio;
  }

  /// Login — typical body: `{ "email", "password" }` (adjust if your API differs).
  Future<Response<Map<String, dynamic>>> login({
    required String email,
    required String password,
    Map<String, dynamic>? extraFields,
    CancelToken? cancelToken,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'password': password,
      if (extraFields != null) ...extraFields,
    };
    return _dio.post<Map<String, dynamic>>(
      AppApiUrls.authLogin,
      data: data,
      cancelToken: cancelToken,
    );
  }

  /// Logout — sends `Authorization: Bearer …` when [accessToken] is set.
  Future<Response<Map<String, dynamic>>> logout({
    String? accessToken,
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<Map<String, dynamic>>(
      AppApiUrls.authLogout,
      data: body ?? <String, dynamic>{},
      cancelToken: cancelToken,
      options: Options(
        headers: accessToken != null && accessToken.isNotEmpty
            ? <String, String>{'Authorization': 'Bearer $accessToken'}
            : null,
      ),
    );
  }

  /// Refresh access token — typical body: `{ "refresh": "<refresh_token>" }`.
  Future<Response<Map<String, dynamic>>> refreshToken({
    required String refreshToken,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<Map<String, dynamic>>(
      AppApiUrls.authTokenRefresh,
      data: {'refresh': refreshToken},
      cancelToken: cancelToken,
    );
  }
}

final authApiClientProvider = Provider<AuthApiClient>(
  (ref) => sl<AuthApiClient>(),
);
