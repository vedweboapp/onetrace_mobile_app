import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:red5/core/logging/app_logger.dart';

const _sensitiveLogKeys = {
  'password',
  'access',
  'refresh',
  'token',
  'authorization',
  'secret',
};

/// Logs every Dio request/response/error via [AppLogger.write].
///
/// Redacts common secret fields; avoids dumping raw binary bodies.
final class ApiDioLogInterceptor extends Interceptor {
  ApiDioLogInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.write(
      'API → ${options.method} ${options.uri}',
      extra: _describeRequestPayload(options.data),
      level: Level.debug,
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final code = response.statusCode ?? 0;
    final uri = response.requestOptions.uri;
    final ok = code >= 200 && code < 300;
    _printApiResponse(
      prefix: 'API RESPONSE',
      method: response.requestOptions.method,
      uri: uri,
      statusCode: code,
      data: response.data,
    );
    AppLogger.write(
      'API ← $code $uri | success=$ok',
      extra: _describeResponsePayload(response.data),
      level: ok ? Level.info : Level.warning,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final code = err.response?.statusCode;
    final uri = err.requestOptions.uri;
    AppLogger.write(
      'API ✗ $uri | status=$code | type=${err.type}',
      error: err,
      stackTrace: err.stackTrace,
      level: Level.error,
    );
    final data = err.response?.data;
    if (data != null) {
      _printApiResponse(
        prefix: 'API ERROR BODY',
        method: err.requestOptions.method,
        uri: uri,
        statusCode: code,
        data: data,
      );
      AppLogger.write(
        'API ✗ body',
        extra: _redactForLog(data),
        level: Level.error,
      );
    }
    handler.next(err);
  }
}

void _printApiResponse({
  required String prefix,
  required String method,
  required Uri uri,
  required int? statusCode,
  required dynamic data,
}) {
  final statusText = statusCode == null ? 'n/a' : '$statusCode';
  final header = '[$prefix] $method $uri | status=$statusText';
  final body = _prettyBody(data);
  debugPrint('$header\n$body');
}

String _prettyBody(dynamic data) {
  if (data == null) return '<empty>';
  try {
    if (data is List<int>) {
      final text = utf8.decode(data, allowMalformed: true);
      final parsed = jsonDecode(text);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    }
    if (data is Map || data is List) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    final raw = data.toString().trim();
    if (raw.startsWith('{') || raw.startsWith('[')) {
      final parsed = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    }
    return raw;
  } catch (_) {
    return data.toString();
  }
}

Object? _redactForLog(Object? value) {
  if (value is Map) {
    return {
      for (final e in value.entries)
        e.key.toString(): _sensitiveLogKeys.contains(e.key.toString().toLowerCase())
            ? '***'
            : _redactForLog(e.value),
    };
  }
  if (value is List) {
    return value.map(_redactForLog).toList();
  }
  return value;
}

String _describeRequestPayload(Object? data) {
  if (data == null) {
    return 'body: <empty>';
  }
  if (data is FormData) {
    final fieldKeys = data.fields.map((e) => e.key).join(', ');
    final fileParts = data.files
        .map((e) => '${e.key}(${e.value.filename ?? 'file'})')
        .join(', ');
    return 'FormData(fields: [$fieldKeys], files: [$fileParts])';
  }
  return 'body: ${_redactForLog(data)}';
}

String _describeResponsePayload(Object? data) {
  if (data == null) {
    return 'data: <empty>';
  }
  if (data is List<int>) {
    return 'data: bytes(len=${data.length})';
  }
  return 'data: ${_redactForLog(data)}';
}
