import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:red5/core/constants/app_strings.dart';

/// Builds short, user-visible text from Dio/network failures and typical JSON APIs
/// ([detail], [message], field validation maps, lists).
abstract final class ApiResponseMessage {
  ApiResponseMessage._();

  /// Best-effort message for any thrown value (e.g. from `catch (e)`).
  static String fromAnyError(
    Object error, {
    String? genericFallback,
  }) {
    if (error is DioException) {
      return fromDioException(error, genericFallback: genericFallback);
    }
    final fallback =
        genericFallback ?? AppStrings.apiErrorGenericDetailFallback;
    final text = error.toString().trim();
    if (text.isEmpty || text == 'Null' || text == 'Instance of \'Exception\'') {
      return fallback;
    }
    return text;
  }

  static String fromDioException(
    DioException e, {
    String? genericFallback,
  }) {
    final fallback =
        genericFallback ?? AppStrings.apiErrorGenericDetailFallback;

    final type = e.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout) {
      return _firstNonBlank([_bodyMessage(e.response), AppStrings.apiErrorTimeout]) ??
          fallback;
    }
    if (type == DioExceptionType.connectionError) {
      return _firstNonBlank([_bodyMessage(e.response), AppStrings.apiErrorNetwork]) ??
          fallback;
    }
    if (type == DioExceptionType.badCertificate) {
      return _firstNonBlank([AppStrings.apiErrorBadCertificate]) ?? fallback;
    }
    if (type == DioExceptionType.cancel) {
      return AppStrings.apiErrorCancelled;
    }

    final status = e.response?.statusCode;
    final fromBody = _bodyMessage(e.response);

    return _firstNonBlank([
          fromBody,
          if (status != null) _messageForStatusCode(status),
          e.message?.trim(),
        ]) ??
        fallback;
  }

  /// When you handle a [Response] yourself (non-throwing Dio, multipart, etc.).
  static String fromHttp({
    required int? statusCode,
    dynamic responseData,
    String? genericFallback,
  }) {
    final fallback =
        genericFallback ?? AppStrings.apiErrorGenericDetailFallback;
    final normalized = _normalizeData(responseData);
    final fromBody = _messageFromPayload(normalized);
    return _firstNonBlank([
          fromBody,
          if (statusCode != null) _messageForStatusCode(statusCode),
        ]) ??
        fallback;
  }

  static String? _bodyMessage(Response<dynamic>? response) {
    if (response == null) return null;
    return _messageFromPayload(_normalizeData(response.data));
  }

  static dynamic _normalizeData(dynamic data) {
    if (data == null) return null;
    if (data is Map || data is List) return data;
    if (data is String) {
      final t = data.trim();
      if (t.isEmpty) return null;
      if (t.startsWith('{') || t.startsWith('[')) {
        try {
          return jsonDecode(t);
        } catch (_) {
          return t;
        }
      }
      return t;
    }
    return data;
  }

  static String? _messageFromPayload(dynamic payload) {
    if (payload == null) return null;
    if (payload is String) {
      final t = payload.trim();
      return t.isEmpty ? null : t;
    }
    if (payload is Map) {
      final payloadMap = Map<String, dynamic>.from(
        payload.map((k, v) => MapEntry(k.toString(), v)),
      );
      final direct = _stringFromNested(payloadMap['message']) ??
          _stringFromNested(payloadMap['error']) ??
          _stringFromNested(payloadMap['title']);
      if (direct != null) return direct;

      final detail = _detailToString(payloadMap['detail']);
      if (detail != null) return detail;

      final nested = payloadMap['errors'];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(
          nested.map((k, v) => MapEntry(k.toString(), v)),
        );
        final fromNestedMap = _firstFieldMessage(nestedMap);
        if (fromNestedMap != null) return fromNestedMap;
      }
      if (nested is List) {
        final s = _listToMessage(nested);
        if (s != null) return s;
      }

      final nfe = payloadMap['non_field_errors'];
      if (nfe is List) {
        final s = _listToMessage(nfe);
        if (s != null) return s;
      }

      final fromFields = _firstFieldMessage(payloadMap);
      if (fromFields != null) return fromFields;

      return null;
    }
    if (payload is List) {
      return _listToMessage(payload);
    }
    final s = payload.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _firstFieldMessage(Map<String, dynamic> map) {
    const skipKeys = {
      'detail',
      'message',
      'error',
      'title',
      'non_field_errors',
      'errors',
    };
    for (final entry in map.entries) {
      if (skipKeys.contains(entry.key)) continue;
      final v = entry.value;
      final msg =
          _stringFromNested(v) ?? (v is List ? _listToMessage(v) : null);
      if (msg != null && msg.trim().isNotEmpty) {
        final clean = msg.trim();
        final lowerKey = entry.key.replaceAll('_', ' ');
        if (clean.toLowerCase().contains(lowerKey.toLowerCase())) {
          return clean;
        }
        return '${entry.key}: $clean';
      }
    }
    return null;
  }

  static String? _stringFromNested(dynamic value) {
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  static String? _detailToString(dynamic detail) {
    if (detail == null) return null;
    if (detail is String) {
      final t = detail.trim();
      return t.isEmpty ? null : t;
    }
    if (detail is List) {
      return _listToMessage(detail);
    }
    if (detail is Map) {
      final code = detail['code'];
      final msg = detail['detail'] ?? detail['message'];
      final pieces = <String>[];
      if (msg != null) pieces.add(msg.toString());
      if (code != null && code.toString().trim().isNotEmpty) {
        pieces.insert(0, code.toString().trim());
      }
      final joined = pieces.join(': ').trim();
      return joined.isEmpty ? null : joined;
    }
    final s = detail.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _listToMessage(List list) {
    if (list.isEmpty) return null;
    final parts = <String>[];
    for (final item in list) {
      if (item is String) {
        final t = item.trim();
        if (t.isNotEmpty) parts.add(t);
      } else if (item is Map) {
        final inner = _detailToString(item) ?? item.toString();
        if (inner.trim().isNotEmpty) parts.add(inner.trim());
      } else {
        final t = item.toString().trim();
        if (t.isNotEmpty) parts.add(t);
      }
    }
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : parts.join(' ');
  }

  static String? _messageForStatusCode(int code) {
    if (code >= 200 && code < 300) return null;
    if (code == 400) return AppStrings.apiErrorBadRequest;
    if (code == 401) return AppStrings.apiErrorUnauthorized;
    if (code == 403) return AppStrings.apiErrorForbidden;
    if (code == 404) return AppStrings.apiErrorNotFound;
    if (code == 409) return AppStrings.apiErrorConflict;
    if (code == 422) return AppStrings.apiErrorValidation;
    if (code == 429) return AppStrings.apiErrorRateLimited;
    if (code == 502 || code == 503 || code == 504) {
      return AppStrings.apiErrorServiceUnavailable;
    }
    if (code >= 500) return AppStrings.apiErrorServer;
    if (code >= 400) return AppStrings.apiErrorBadRequest;
    return null;
  }

  static String? _firstNonBlank(Iterable<String?> candidates) {
    for (final c in candidates) {
      final t = c?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }
}
