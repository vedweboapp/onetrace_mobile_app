import 'package:flutter/foundation.dart';

/// Lightweight reference to a composite item used by the group dropdown.
@immutable
class CompositeItemRef {
  const CompositeItemRef({required this.id, required this.name});

  final String id;
  final String name;

  static CompositeItemRef? fromJson(Map<String, dynamic> json) {
    final id = _readString(json, const ['id']);
    if (id.isEmpty) return null;
    final name = _readString(json, const [
      'name',
      'item_name',
      'composite_item_name',
    ], fallback: 'Composite Item');
    return CompositeItemRef(id: id, name: name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CompositeItemRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Row in a group: a composite item with an optional short abbreviation.
@immutable
class GroupItem {
  const GroupItem({required this.compositeItem, required this.abbreviation});

  final CompositeItemRef compositeItem;
  final String abbreviation;

  static GroupItem? fromJson(Map<String, dynamic> json) {
    final ref = _resolveCompositeItem(json);
    if (ref == null) return null;
    return GroupItem(
      compositeItem: ref,
      abbreviation: _readString(json, const [
        'abbreviation',
        'short_code',
        'code',
      ]),
    );
  }

  static CompositeItemRef? _resolveCompositeItem(Map<String, dynamic> json) {
    final nested = json['composite_item'];
    if (nested is Map) {
      return CompositeItemRef.fromJson(Map<String, dynamic>.from(nested));
    }
    final id = _readString(json, const [
      'composite_item_id',
      'composite_item',
      'item_id',
    ]);
    if (id.isEmpty) return null;
    final name = _readString(json, const [
      'composite_item_name',
      'item_name',
      'name',
    ], fallback: 'Composite Item');
    return CompositeItemRef(id: id, name: name);
  }
}

@immutable
class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByName,
    required this.createdByEmail,
    required this.modifiedByName,
    required this.modifiedByEmail,
  });

  final String id;
  final String name;
  final bool isActive;
  final List<GroupItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdByName;
  final String createdByEmail;
  final String modifiedByName;
  final String modifiedByEmail;

  static GroupModel fromJson(Map<String, dynamic> json) {
    final rawItems = json['composite_items'] ?? json['items'] ?? json['rows'];
    final items = <GroupItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map) {
          final parsed = GroupItem.fromJson(Map<String, dynamic>.from(entry));
          if (parsed != null) items.add(parsed);
        }
      }
    }
    return GroupModel(
      id: _readString(json, const ['id']),
      name: _readString(json, const [
        'name',
        'group_name',
      ], fallback: 'Group Name'),
      isActive: _readBool(json, const ['is_active', 'active', 'status']),
      items: items,
      createdAt: _readDateTime(json, const ['created_at', 'createdAt']),
      updatedAt: _readDateTime(json, const ['updated_at', 'updatedAt']),
      createdByName: _readNestedString(json, 'created_by', const [
        'name',
        'full_name',
        'username',
      ]),
      createdByEmail: _readNestedString(json, 'created_by', const [
        'email',
        'email_address',
      ]),
      modifiedByName: _readNestedString(json, 'modified_by', const [
        'name',
        'full_name',
        'username',
      ]),
      modifiedByEmail: _readNestedString(json, 'modified_by', const [
        'email',
        'email_address',
      ]),
    );
  }
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

bool _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw.toString().trim().toLowerCase();
    if (text.isEmpty) continue;
    if (text == 'true' || text == 'active' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' ||
        text == 'inactive' ||
        text == 'in_active' ||
        text == '0' ||
        text == 'no') {
      return false;
    }
  }
  return true;
}

DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    if (raw is DateTime) return raw;
    final text = raw.toString().trim();
    if (text.isEmpty) continue;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed.toLocal();
  }
  return null;
}

String _readNestedString(
  Map<String, dynamic> json,
  String parentKey,
  List<String> keys,
) {
  final raw = json[parentKey];
  if (raw is Map) {
    return _readString(Map<String, dynamic>.from(raw), keys);
  }
  return '';
}
