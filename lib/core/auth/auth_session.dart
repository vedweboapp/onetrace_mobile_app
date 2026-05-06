import 'dart:convert';

/// Helpers for extracting and validating auth session token payloads.
abstract final class AuthSession {
  AuthSession._();

  static String? readAccessToken(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    return _readFirstString(payload, const [
      'access',
      'access_token',
      'token',
      'jwt',
    ]);
  }

  static String? readRefreshToken(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    return _readFirstString(payload, const ['refresh', 'refresh_token']);
  }

  static bool isJwtValid(String? token, {Duration skew = const Duration(seconds: 20)}) {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    final parts = trimmed.split('.');
    if (parts.length < 2) return true;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson);
      if (payload is! Map) return true;
      final expRaw = payload['exp'];
      final expSeconds = expRaw is int ? expRaw : int.tryParse('$expRaw');
      if (expSeconds == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        expSeconds * 1000,
        isUtc: true,
      );
      return DateTime.now().toUtc().add(skew).isBefore(expiry);
    } catch (_) {
      return true;
    }
  }

  static String? _readFirstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final nested = map['data'];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(
        nested.map((k, v) => MapEntry(k.toString(), v)),
      );
      for (final key in keys) {
        final v = nestedMap[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }
}
