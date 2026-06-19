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

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
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
