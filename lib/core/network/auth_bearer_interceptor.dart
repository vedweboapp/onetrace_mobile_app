import 'package:dio/dio.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';

/// Injects `Authorization: Bearer <access_token>` from local storage.
final class AuthBearerInterceptor extends Interceptor {
  AuthBearerInterceptor(this._storage);

  final LocalStorage _storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final existingAuth = options.headers['Authorization'];
    if (existingAuth is String && existingAuth.trim().isNotEmpty) {
      handler.next(options);
      return;
    }

    final token = _storage.getString(LocalStorageKeys.authAccessToken)?.trim();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
