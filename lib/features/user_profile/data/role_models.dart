import 'package:flutter/foundation.dart';

/// One row from `GET /api/v1/role/` list `data[]`.
@immutable
final class RoleModel {
  const RoleModel({
    required this.id,
    required this.roleName,
  });

  final String id;
  final String roleName;

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: _readId(json['id']),
      roleName: _readString(json, const ['role_name', 'name', 'title']),
    );
  }

  static String _readId(dynamic raw) {
    if (raw == null) return '';
    if (raw is int) return raw.toString();
    final t = raw.toString().trim();
    return t;
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final raw = map[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isEmpty || text == 'null') continue;
      return text;
    }
    return '';
  }
}
