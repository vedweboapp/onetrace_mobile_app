import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/network/success_toast_interceptor.dart';

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
      options: Options(
        extra: <String, dynamic>{
          kDioExtraShowSuccessToast: true,
          kDioExtraSuccessToastTitle: 'Successfully logged in',
        },
      ),
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

  /// Send a one-time password to [email] for sign-in.
  Future<Response<Map<String, dynamic>>> sendOtp({
    required String email,
    Map<String, dynamic>? extraFields,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<Map<String, dynamic>>(
      AppApiUrls.authSendOtp,
      data: <String, dynamic>{
        'email': email,
        if (extraFields != null) ...extraFields,
      },
      cancelToken: cancelToken,
    );
  }

  /// Re-send the most recently issued OTP for [email].
  Future<Response<Map<String, dynamic>>> resendOtp({
    required String email,
    Map<String, dynamic>? extraFields,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<Map<String, dynamic>>(
      AppApiUrls.authResendOtp,
      data: <String, dynamic>{
        'email': email,
        if (extraFields != null) ...extraFields,
      },
      cancelToken: cancelToken,
    );
  }

  /// Verify a 6-digit [otp] for [email]. On the sign-in flow the response
  /// typically contains access/refresh tokens.
  Future<Response<Map<String, dynamic>>> verifyOtp({
    required String email,
    required String otp,
    Map<String, dynamic>? extraFields,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<Map<String, dynamic>>(
      AppApiUrls.authVerifyOtp,
      data: <String, dynamic>{
        'email': email,
        'otp': otp,
        if (extraFields != null) ...extraFields,
      },
      cancelToken: cancelToken,
    );
  }

  /// Forgot-password endpoint. The same endpoint is used in two ways:
  ///
  /// * Call with just [email] to request the password-reset OTP / email.
  /// * After OTP verification, call with [email] + [newPassword] +
  ///   [newPasswordConfirm] to commit the new password.
  Future<Response<Map<String, dynamic>>> forgotPassword({
    required String email,
    String? newPassword,
    String? newPasswordConfirm,
    Map<String, dynamic>? extraFields,
    CancelToken? cancelToken,
  }) async {
    return _dio.post<Map<String, dynamic>>(
      AppApiUrls.authForgotPassword,
      data: <String, dynamic>{
        'email': email,
        if (newPassword != null) 'new_password': newPassword,
        if (newPasswordConfirm != null)
          'new_password_confirm': newPasswordConfirm,
        if (extraFields != null) ...extraFields,
      },
      cancelToken: cancelToken,
    );
  }

  Map<String, dynamic> _inviteSuccessToastExtra(Map<String, dynamic> data) {
    final email = data['email']?.toString().trim() ?? '';
    return <String, dynamic>{
      kDioExtraShowSuccessToast: true,
      kDioExtraSuccessToastTitle: 'Invite sent successfully',
      if (email.isNotEmpty)
        kDioExtraSuccessToastSubtitle: '$email will receive an email shortly.',
    };
  }

  /// Invite a new user. When [profilePhotoBytes] is provided the request is
  /// sent as `multipart/form-data` so the photo can be uploaded alongside
  /// [data]; otherwise it's a regular JSON POST.
  Future<Response<Map<String, dynamic>>> inviteUser({
    required Map<String, dynamic> data,
    Uint8List? profilePhotoBytes,
    String profilePhotoFieldName = 'profile_photo',
    String profilePhotoFileName = 'profile.jpg',
    CancelToken? cancelToken,
  }) async {
    if (profilePhotoBytes != null && profilePhotoBytes.isNotEmpty) {
      final form = FormData.fromMap(<String, dynamic>{
        ...data,
        profilePhotoFieldName: MultipartFile.fromBytes(
          profilePhotoBytes,
          filename: profilePhotoFileName,
        ),
      });
      return _dio.post<Map<String, dynamic>>(
        AppApiUrls.authInviteUser,
        data: form,
        cancelToken: cancelToken,
        options: Options(
          contentType: 'multipart/form-data',
          extra: _inviteSuccessToastExtra(data),
        ),
      );
    }
    return _dio.post<Map<String, dynamic>>(
      AppApiUrls.authInviteUser,
      data: data,
      cancelToken: cancelToken,
      options: Options(extra: _inviteSuccessToastExtra(data)),
    );
  }
}

final authApiClientProvider = Provider<AuthApiClient>(
  (ref) => sl<AuthApiClient>(),
);
