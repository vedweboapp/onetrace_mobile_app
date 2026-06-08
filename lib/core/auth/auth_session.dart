import 'dart:convert';

/// Helpers for extracting and validating auth session token payloads.
abstract final class AuthSession {
  AuthSession._();

  static const _accessKeys = ['access', 'access_token', 'token', 'jwt'];
  static const _refreshKeys = ['refresh', 'refresh_token'];

  /// Normalizes Dio JSON (`Map<dynamic, dynamic>`) for token helpers.
  static Map<String, dynamic>? coerceAuthPayload(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static String? readAccessToken(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    for (final map in _payloadCandidates(payload)) {
      final direct = _readFirstString(map, _accessKeys);
      if (direct != null) return direct;
      final tokens = map['tokens'];
      if (tokens is Map) {
        final tokensMap = Map<String, dynamic>.from(
          tokens.map((k, v) => MapEntry(k.toString(), v)),
        );
        final nested = _readFirstString(tokensMap, _accessKeys);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static String? readRefreshToken(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    for (final map in _payloadCandidates(payload)) {
      final direct = _readFirstString(map, _refreshKeys);
      if (direct != null) return direct;
      final tokens = map['tokens'];
      if (tokens is Map) {
        final tokensMap = Map<String, dynamic>.from(
          tokens.map((k, v) => MapEntry(k.toString(), v)),
        );
        final nested = _readFirstString(tokensMap, _refreshKeys);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _payloadCandidates(
    Map<String, dynamic> payload,
  ) {
    final out = <Map<String, dynamic>>[];
    final seen = <int>{};

    void addMap(Map<String, dynamic> map) {
      final id = identityHashCode(map);
      if (seen.add(id)) out.add(map);
    }

    void walk(dynamic node) {
      if (node is! Map) return;
      final map = Map<String, dynamic>.from(
        node.map((k, v) => MapEntry(k.toString(), v)),
      );
      addMap(map);
      for (final key in const [
        'data',
        'result',
        'response',
        'user',
        'tokens',
      ]) {
        walk(map[key]);
      }
    }

    walk(payload);
    return out;
  }

  /// Organization id from login / verify-otp JSON (`organization`, `organization_id`, …).
  static int? readOrganizationId(Map<String, dynamic>? payload) {
    if (payload == null) return null;

    int? parseId(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      if (value is Map) {
        final nested = value['id'] ?? value['pk'];
        return parseId(nested);
      }
      return null;
    }

    int? fromMap(Map<String, dynamic> map) {
      for (final key in const [
        'organization_id',
        'organizationId',
        'org_id',
        'orgId',
      ]) {
        final id = parseId(map[key]);
        if (id != null) return id;
      }
      final org = map['organization'];
      final id = parseId(org);
      if (id != null) return id;

      final user = map['user'];
      if (user is Map) {
        final userMap = Map<String, dynamic>.from(
          user.map((k, v) => MapEntry(k.toString(), v)),
        );
        return fromMap(userMap);
      }
      return null;
    }

    final fromRoot = fromMap(payload);
    if (fromRoot != null) return fromRoot;

    final nested = payload['data'];
    if (nested is Map) {
      return fromMap(
        Map<String, dynamic>.from(
          nested.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
    }
    return null;
  }

  /// `data.user.id` (or top-level `user.id`) from login / verify-otp JSON.
  static String? readUserId(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    String? fromMap(Map<String, dynamic> map) {
      final u = map['user'];
      if (u is! Map) return null;
      final id = u['id'];
      if (id == null) return null;
      final s = id.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return s;
    }

    final fromRoot = fromMap(payload);
    if (fromRoot != null) return fromRoot;

    final nested = payload['data'];
    if (nested is Map) {
      final dataMap = Map<String, dynamic>.from(
        nested.map((k, v) => MapEntry(k.toString(), v)),
      );
      return fromMap(dataMap);
    }
    return null;
  }

  /// Role slug from common login payload keys (`role`, `user.role`, `groups`, etc.).
  static String? readRoleSlug(Map<String, dynamic>? payload) {
    if (payload == null) return null;

    String? fromValue(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final text = value.trim().toLowerCase();
        return text.isEmpty ? null : text;
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
        return fromValue(map['slug']) ??
            fromValue(map['name']) ??
            fromValue(map['role']) ??
            fromValue(map['title']);
      }
      if (value is List) {
        for (final item in value) {
          final role = fromValue(item);
          if (role != null) return role;
        }
      }
      return null;
    }

    String? fromMap(Map<String, dynamic> map) {
      for (final key in const [
        'role',
        'user_role',
        'role_name',
        'role_slug',
        'group',
        'groups',
      ]) {
        final role = fromValue(map[key]);
        if (role != null) return role;
      }
      final user = map['user'];
      if (user is Map) {
        return fromMap(
          Map<String, dynamic>.from(
            user.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
      }
      return null;
    }

    for (final map in _payloadCandidates(payload)) {
      final role = fromMap(map);
      if (role != null) return role;
    }
    return null;
  }

  static bool isJwtValid(
    String? token, {
    Duration skew = const Duration(seconds: 20),
  }) {
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
