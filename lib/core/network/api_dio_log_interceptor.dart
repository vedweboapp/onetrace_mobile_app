import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

/// Max characters per [debugPrint] chunk (Android logcat truncates long lines).
const _logChunkSize = 800;

/// Logs every Dio request/response/error with the **full** body (chunked).
final class ApiDioLogInterceptor extends Interceptor {
  ApiDioLogInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _logBlock(
        title: 'API REQUEST',
        lines: [
          '${options.method} ${options.uri}',
          if (options.queryParameters.isNotEmpty)
            'query: ${_prettyJson(options.queryParameters)}',
          if (options.headers.isNotEmpty)
            'headers: ${_prettyJson(_redactForLog(options.headers))}',
          'body: ${_describeRequestPayload(options.data)}',
        ],
      );
    } else {
      AppLogger.write(
        'API → ${options.method} ${options.uri}',
        extra: _describeRequestPayload(options.data),
        level: Level.debug,
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final code = response.statusCode ?? 0;
    final uri = response.requestOptions.uri;
    final ok = code >= 200 && code < 300;

    if (kDebugMode) {
      _logBlock(
        title: 'API RESPONSE | HTTP $code',
        lines: [
          '${response.requestOptions.method} $uri',
          'body:',
          _prettyBody(response.data),
        ],
      );
    } else {
      AppLogger.write(
        'API ← $code $uri | success=$ok',
        level: ok ? Level.info : Level.warning,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final code = err.response?.statusCode;
    final uri = err.requestOptions.uri;

    if (kDebugMode) {
      _logBlock(
        title: 'API ERROR | HTTP ${code ?? 'n/a'} | ${err.type}',
        lines: [
          '${err.requestOptions.method} $uri',
          'message: ${err.message ?? 'n/a'}',
          if (err.response?.data != null) ...[
            'error body:',
            _prettyBody(err.response!.data),
          ],
        ],
      );
    } else {
      AppLogger.write(
        'API ✗ $uri | status=$code | type=${err.type}',
        error: err,
        stackTrace: err.stackTrace,
        level: Level.error,
      );
    }
    handler.next(err);
  }
}

void _logBlock({required String title, required List<String> lines}) {
  final divider = '═' * 72;
  _logChunked('');
  _logChunked('╔$divider');
  _logChunked('║ $title');
  _logChunked('╠$divider');
  for (final line in lines) {
    if (line.contains('\n')) {
      for (final sub in line.split('\n')) {
        _logChunked('║ $sub');
      }
    } else {
      _logChunked('║ $line');
    }
  }
  _logChunked('╚$divider');
}

void _logChunked(String message) {
  if (message.length <= _logChunkSize) {
    debugPrint(message);
    return;
  }
  var offset = 0;
  while (offset < message.length) {
    final end = (offset + _logChunkSize).clamp(0, message.length);
    debugPrint(message.substring(offset, end));
    offset = end;
  }
}

String _prettyBody(dynamic data) {
  if (data == null) return '<empty>';
  try {
    if (data is List<int>) {
      final text = utf8.decode(data, allowMalformed: true);
      return _prettyJson(jsonDecode(text));
    }
    if (data is Map || data is List) {
      return _prettyJson(data);
    }
    final raw = data.toString().trim();
    if (raw.startsWith('{') || raw.startsWith('[')) {
      return _prettyJson(jsonDecode(raw));
    }
    return raw;
  } catch (_) {
    return data.toString();
  }
}

String _prettyJson(Object? value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
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
    return '<empty>';
  }
  if (data is FormData) {
    final fieldKeys = data.fields.map((e) => e.key).join(', ');
    final fileParts = data.files
        .map((e) => '${e.key}(${e.value.filename ?? 'file'})')
        .join(', ');
    return 'FormData(fields: [$fieldKeys], files: [$fileParts])';
  }
  return _prettyJson(_redactForLog(data));
}
