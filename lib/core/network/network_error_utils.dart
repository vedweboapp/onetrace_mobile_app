import 'package:dio/dio.dart';

bool isRecoverableNetworkError(Object error) {
  if (error is DioException) {
    final type = error.type;
    return type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.unknown;
  }
  return false;
}
