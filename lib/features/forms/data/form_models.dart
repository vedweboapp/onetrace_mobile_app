import 'package:flutter/foundation.dart';

@immutable
final class FormSummary {
  const FormSummary({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final Map<String, dynamic> raw;

  /// Template form id when this row is a project-form link (`form.id`).
  int? get templateFormId {
    final nested = raw['form'];
    if (nested is Map) {
      final map = Map<String, dynamic>.from(
        nested.map((k, v) => MapEntry(k.toString(), v)),
      );
      return _readInt(map['id']);
    }
    return _readInt(raw['form_id']);
  }

  String? get projectTypeLabel =>
      _readNestedLabel(raw, 'project_type', const [
        'project_type',
        'type_name',
        'name',
        'title',
        'label',
      ]);

  String? get installationTypeLabel =>
      _readNestedLabel(raw, 'installation_type', const [
        'installation_type',
        'type_name',
        'name',
        'title',
        'label',
      ]);

  /// Installation type id on the `project_form` assignment row (not template `form`).
  int? get installationTypeId => readProjectFormInstallationTypeId(raw);

  DateTime? get createdAt =>
      _readDate(raw['created_at'] ?? raw['createdAt']);

  factory FormSummary.fromJson(Map<String, dynamic> json) {
    final nestedForm = json['form'];
    final nestedMap = nestedForm is Map
        ? Map<String, dynamic>.from(
            nestedForm.map((k, v) => MapEntry(k.toString(), v)),
          )
        : const <String, dynamic>{};

    final idRaw = json['id'] ?? json['project_form_id'] ?? nestedMap['id'];
    final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}') ?? 0;
    return FormSummary(
      id: id,
      name: _readString(json, const [
            'form_name',
            'name',
            'title',
            'label',
          ]) ??
          _readString(nestedMap, const [
            'form_name',
            'name',
            'title',
            'label',
          ]) ??
          'Form $id',
      description: _readString(json, const ['description', 'details']) ??
          _readString(nestedMap, const ['description', 'details']),
      isActive: _readBool(json['is_active']) ?? _readBool(nestedMap['is_active']) ?? true,
      raw: Map<String, dynamic>.from(json),
    );
  }
}

String? _readNestedLabel(
  Map<String, dynamic> map,
  String key,
  List<String> nameKeys,
) {
  final nested = map[key];
  if (nested is Map) {
    final nestedMap = Map<String, dynamic>.from(
      nested.map((k, v) => MapEntry(k.toString(), v)),
    );
    final fromNested = _readString(nestedMap, nameKeys);
    if (fromNested != null) return fromNested;
  }
  return _readString(map, ['${key}_name', '${key}_label', key]);
}

/// Reads installation type id from a `project_form` row (and its `project_type`).
int? readProjectFormInstallationTypeId(Map<String, dynamic> map) {
  final direct = readInstallationTypeId(map);
  if (direct != null) return direct;

  final projectType = map['project_type'];
  if (projectType is Map) {
    return readInstallationTypeId(
      Map<String, dynamic>.from(
        projectType.map((k, v) => MapEntry(k.toString(), v)),
      ),
    );
  }
  return null;
}

/// Reads installation type id from item / project-form / pin payloads.
int? readInstallationTypeId(Map<String, dynamic> map) {
  for (final key in const [
    'installation_type_id',
    'installationTypeId',
    'installation_type',
  ]) {
    final raw = map[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is Map) {
      final nested = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      final nestedId = _readInt(nested['id']);
      if (nestedId != null) return nestedId;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final rowId = _readInt(map['id']);
      if (rowId != null) return rowId;
    }
    if (raw != null) {
      final parsed = int.tryParse(raw.toString().trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

DateTime? _readDate(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    if (value is Map || value is List) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  if (value == null) return null;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
}
