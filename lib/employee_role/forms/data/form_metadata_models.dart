/// Parsed form layout from `GET /forms/{id}/metadata/`.
library;

import 'package:flutter/foundation.dart';

@immutable
final class FormMetadataSection {
  const FormMetadataSection({
    required this.id,
    required this.name,
    required this.sequence,
    required this.columnCount,
    required this.isActive,
    required this.fields,
  });

  final int id;
  final String name;
  final int sequence;
  final int columnCount;
  final bool isActive;
  final List<FormMetadataField> fields;
}

@immutable
final class FormMetadataField {
  const FormMetadataField({
    required this.id,
    required this.label,
    required this.apiName,
    required this.fieldType,
    required this.sequence,
    this.placeholder,
    this.helpText,
    this.options = const [],
    this.isActive = true,
    this.isRequired = false,
    this.isReadonly = false,
    this.isHidden = false,
    this.maxLength,
    this.minLength,
    this.maxFileSizeMb,
    this.multiLineRows = 4,
  });

  final int id;
  final String label;
  final String apiName;
  final String fieldType;
  final int sequence;
  final String? placeholder;
  final String? helpText;
  final List<String> options;
  final bool isActive;
  final bool isRequired;
  final bool isReadonly;
  final bool isHidden;
  final int? maxLength;
  final int? minLength;
  final int? maxFileSizeMb;
  final int multiLineRows;

  bool get isVisible => isActive && !isHidden;

  factory FormMetadataField.fromMap(Map<String, dynamic> map) {
    final properties = _readMap(map['properties']);
    final validation = _readMap(properties['validation_rules']);
    final optionsRaw = map['options'];
    final options = optionsRaw is List
        ? optionsRaw
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return FormMetadataField(
      id: _readInt(map['id']) ?? 0,
      label: _readString(map, const ['field_label', 'label', 'name']) ??
          'Field',
      apiName: _readString(map, const ['api_name']) ?? 'field_${map['id']}',
      fieldType: (_readString(map, const ['field_type', 'type']) ?? 'single_line')
          .trim()
          .toLowerCase(),
      sequence: _readInt(map['sequence']) ?? 0,
      placeholder: _readString(map, const ['placeholder']),
      helpText: _readString(map, const ['help_text']),
      options: options,
      isActive: _readBool(map['is_active']) ?? true,
      isRequired: _readBool(properties['is_required']) ?? false,
      isReadonly: _readBool(properties['is_readonly']) ?? false,
      isHidden: _readBool(properties['is_hidden']) ?? false,
      maxLength: _readInt(validation['max_length']),
      minLength: _readInt(validation['min_length']),
      maxFileSizeMb: _readInt(validation['max_file_size']),
      multiLineRows: _readInt(validation['rows']) ?? 4,
    );
  }
}

/// Reads [sections] from form metadata (`GET /forms/{id}/metadata/`).
List<FormMetadataSection> parseFormMetadataSections(
  Map<String, dynamic> metadata,
) {
  final raw = metadata['sections'];
  if (raw is! List) return const [];

  final sections = <FormMetadataSection>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(
      entry.map((k, v) => MapEntry(k.toString(), v)),
    );
    if (_readBool(map['is_active']) == false) continue;

    final fieldsRaw = map['fields'];
    final fields = <FormMetadataField>[];
    if (fieldsRaw is List) {
      for (final fieldEntry in fieldsRaw) {
        if (fieldEntry is! Map) continue;
        final field = FormMetadataField.fromMap(
          Map<String, dynamic>.from(
            fieldEntry.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
        if (field.isVisible) fields.add(field);
      }
    }
    fields.sort((a, b) => a.sequence.compareTo(b.sequence));
    if (fields.isEmpty) continue;

    sections.add(
      FormMetadataSection(
        id: _readInt(map['id']) ?? sections.length + 1,
        name: _readString(map, const ['name']) ?? 'Section',
        sequence: _readInt(map['sequence']) ?? sections.length + 1,
        columnCount: _readInt(map['column_count']) ?? 1,
        isActive: _readBool(map['is_active']) ?? true,
        fields: fields,
      ),
    );
  }

  sections.sort((a, b) => a.sequence.compareTo(b.sequence));
  return sections;
}

/// Fields handled outside the operative dynamic form (job checklist / admin).
bool isOperativeExcludedFormField(FormMetadataField field) {
  final api = field.apiName.trim().toLowerCase();
  final label = field.label.trim().toLowerCase();

  if (api == 'material_used' ||
      api == 'materials_used' ||
      api.contains('material_used')) {
    return true;
  }
  if (label.contains('material used')) return true;

  if (api.contains('site_manager') && api.contains('sign')) return true;
  if (api == 'site_manager_signature' ||
      api == 'manager_signature' ||
      api == 'site_manager_sign') {
    return true;
  }
  if (label.contains('site manager') && label.contains('sign')) return true;

  if (_isBeforeAfterPhotoField(field)) return true;

  return false;
}

bool _isBeforeAfterPhotoField(FormMetadataField field) {
  final api = field.apiName.trim().toLowerCase();
  final label = field.label.trim().toLowerCase();

  const apiNames = {
    'before_photo',
    'after_photo',
    'before_image',
    'after_image',
    'before_photos',
    'after_photos',
  };
  if (apiNames.contains(api)) return true;

  final mentionsPhotoOrImage =
      label.contains('photo') || label.contains('image');
  if (mentionsPhotoOrImage &&
      (label.contains('before') || label.contains('after'))) {
    return true;
  }
  if (label.contains('before & after') || label.contains('before and after')) {
    return true;
  }

  if ((api.contains('before') || api.contains('after')) &&
      (api.contains('photo') || api.contains('image'))) {
    return true;
  }

  return false;
}

bool isOperativeExcludedFormSection(FormMetadataSection section) {
  final name = section.name.trim().toLowerCase();
  if (name.isEmpty) return false;

  final mentionsPhotoOrImage =
      name.contains('photo') || name.contains('image');
  if (!mentionsPhotoOrImage) return false;

  return name.contains('before') ||
      name.contains('after') ||
      name.contains('before & after') ||
      name.contains('before and after');
}

/// Hides operative-managed fields from the technician form screen.
List<FormMetadataSection> filterOperativeFormSections(
  List<FormMetadataSection> sections,
) {
  final filtered = <FormMetadataSection>[];
  for (final section in sections) {
    if (isOperativeExcludedFormSection(section)) continue;
    final fields = section.fields
        .where((field) => !isOperativeExcludedFormField(field))
        .toList(growable: false);
    if (fields.isEmpty) continue;
    filtered.add(
      FormMetadataSection(
        id: section.id,
        name: section.name,
        sequence: section.sequence,
        columnCount: section.columnCount,
        isActive: section.isActive,
        fields: fields,
      ),
    );
  }
  return filtered;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;
  if (value == null) return null;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
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

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return const <String, dynamic>{};
}
