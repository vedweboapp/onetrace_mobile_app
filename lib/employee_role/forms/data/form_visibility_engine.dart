import 'package:flutter/foundation.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';

/// Evaluates form metadata `rules[].logic.blocks` show/hide actions.
@immutable
final class FormVisibilitySnapshot {
  const FormVisibilitySnapshot({
    required this.visibleSectionIds,
    required this.visibleFieldIds,
  });

  final Set<int> visibleSectionIds;
  final Set<int> visibleFieldIds;

  bool isSectionVisible(FormMetadataSection section) =>
      visibleSectionIds.contains(section.id);

  bool isFieldVisible(FormMetadataField field) =>
      visibleFieldIds.contains(field.id);

  List<FormMetadataSection> visibleSections(
    List<FormMetadataSection> sections,
  ) {
    final result = <FormMetadataSection>[];
    for (final section in sections) {
      if (!isSectionVisible(section)) continue;
      final fields = section.fields
          .where(isFieldVisible)
          .toList(growable: false);
      if (fields.isEmpty) continue;
      result.add(
        FormMetadataSection(
          id: section.id,
          sid: section.sid,
          name: section.name,
          sequence: section.sequence,
          columnCount: section.columnCount,
          isActive: section.isActive,
          fields: fields,
        ),
      );
    }
    return result;
  }
}

final class FormVisibilityEngine {
  FormVisibilityEngine({
    required List<FormMetadataSection> sections,
    required List<Map<String, dynamic>> rules,
  })  : _sections = sections,
        _blocks = _extractBlocks(rules),
        _sectionIds = sections.map((section) => section.id).toSet(),
        _fieldIds = {
          for (final section in sections)
            for (final field in section.fields) field.id,
        },
        _showOnlySectionIds = _collectShowTargets(
          _extractBlocks(rules),
          sections,
          targetSections: true,
        ),
        _showOnlyFieldIds = _collectShowTargets(
          _extractBlocks(rules),
          sections,
          targetSections: false,
        );

  final List<FormMetadataSection> _sections;
  final List<Map<String, dynamic>> _blocks;
  final Set<int> _sectionIds;
  final Set<int> _fieldIds;
  final Set<int> _showOnlySectionIds;
  final Set<int> _showOnlyFieldIds;

  bool get hasRules => _blocks.isNotEmpty;

  FormVisibilitySnapshot evaluate(Map<String, String?> values) {
    if (_blocks.isEmpty) {
      return FormVisibilitySnapshot(
        visibleSectionIds: Set<int>.from(_sectionIds),
        visibleFieldIds: Set<int>.from(_fieldIds),
      );
    }

    final visibleSections = <int>{
      for (final id in _sectionIds)
        if (!_showOnlySectionIds.contains(id)) id,
    };
    final visibleFields = <int>{
      for (final id in _fieldIds)
        if (!_showOnlyFieldIds.contains(id)) id,
    };

    for (final block in _blocks) {
      if (_matchesCondition(block, values)) {
        _applyActions(
          block['output_fields'],
          sections: _sections,
          visibleSections: visibleSections,
          visibleFields: visibleFields,
        );
      } else {
        final elseBlocks = block['else_blocks'];
        if (elseBlocks is! List) continue;
        for (final entry in elseBlocks) {
          if (entry is! Map) continue;
          final elseBlock = Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (!_matchesElseBlock(elseBlock, block, values)) continue;
          _applyActions(
            elseBlock['else_output_fields'],
            sections: _sections,
            visibleSections: visibleSections,
            visibleFields: visibleFields,
          );
        }
      }
    }

    return FormVisibilitySnapshot(
      visibleSectionIds: visibleSections,
      visibleFieldIds: visibleFields,
    );
  }

  static List<Map<String, dynamic>> _extractBlocks(
    List<Map<String, dynamic>> rules,
  ) {
    final blocks = <Map<String, dynamic>>[];
    for (final rule in rules) {
      final logic = rule['logic'];
      if (logic is! Map) continue;
      final rawBlocks = logic['blocks'];
      if (rawBlocks is! List) continue;
      for (final entry in rawBlocks) {
        if (entry is! Map) continue;
        blocks.add(
          Map<String, dynamic>.from(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }
    return blocks;
  }

  static Set<int> _collectShowTargets(
    List<Map<String, dynamic>> blocks,
    List<FormMetadataSection> sections, {
    required bool targetSections,
  }) {
    final targets = <int>{};
    for (final block in blocks) {
      _collectShowTargetsFromActions(
        block['output_fields'],
        sections,
        targetSections: targetSections,
        into: targets,
      );
      final elseBlocks = block['else_blocks'];
      if (elseBlocks is List) {
        for (final entry in elseBlocks) {
          if (entry is! Map) continue;
          _collectShowTargetsFromActions(
            entry['else_output_fields'],
            sections,
            targetSections: targetSections,
            into: targets,
          );
        }
      }
    }
    return targets;
  }

  static void _collectShowTargetsFromActions(
    dynamic rawActions,
    List<FormMetadataSection> sections, {
    required bool targetSections,
    required Set<int> into,
  }) {
    if (rawActions is! List) return;
    for (final entry in rawActions) {
      if (entry is! Map) continue;
      final action = Map<String, dynamic>.from(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (_readAction(action) != _FormRuleAction.show) continue;
      final targetType = _readTargetType(action);
      if (targetSections) {
        if (targetType != _FormRuleTarget.section) continue;
        final id = _resolveSectionId(action, sections);
        if (id != null) into.add(id);
      } else {
        if (targetType != _FormRuleTarget.field) continue;
        final id = _resolveFieldId(action, sections);
        if (id != null) into.add(id);
      }
    }
  }

  void _applyActions(
    dynamic rawActions, {
    required List<FormMetadataSection> sections,
    required Set<int> visibleSections,
    required Set<int> visibleFields,
  }) {
    if (rawActions is! List) return;
    for (final entry in rawActions) {
      if (entry is! Map) continue;
      final actionMap = Map<String, dynamic>.from(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
      final action = _readAction(actionMap);
      final targetType = _readTargetType(actionMap);
      switch (targetType) {
        case _FormRuleTarget.section:
          final id = _resolveSectionId(actionMap, sections);
          if (id == null) continue;
          if (action == _FormRuleAction.show) {
            visibleSections.add(id);
          } else if (action == _FormRuleAction.hide) {
            visibleSections.remove(id);
          }
        case _FormRuleTarget.field:
          final id = _resolveFieldId(actionMap, sections);
          if (id == null) continue;
          if (action == _FormRuleAction.show) {
            visibleFields.add(id);
          } else if (action == _FormRuleAction.hide) {
            visibleFields.remove(id);
          }
        case _FormRuleTarget.unknown:
          break;
      }
    }
  }

  bool _matchesCondition(
    Map<String, dynamic> block,
    Map<String, String?> values,
  ) {
    final condition = _readString(block['condition'])?.toLowerCase() ?? 'is';
    final expected = _readString(block['value']) ?? '';
    final actual = _readTriggerValue(block, values) ?? '';

    switch (condition) {
      case 'is':
      case 'equals':
      case 'equal':
      case '==':
        return _equals(actual, expected);
      case 'is_not':
      case 'not':
      case '!=':
        return !_equals(actual, expected);
      case 'contains':
        return actual.toLowerCase().contains(expected.toLowerCase());
      case 'is_empty':
      case 'empty':
        return actual.trim().isEmpty;
      case 'is_not_empty':
      case 'not_empty':
        return actual.trim().isNotEmpty;
      default:
        return _equals(actual, expected);
    }
  }

  bool _matchesElseBlock(
    Map<String, dynamic> elseBlock,
    Map<String, dynamic> parentBlock,
    Map<String, String?> values,
  ) {
    final elseValue = _readString(elseBlock['else_value']);
    if (elseValue == null) return true;

    final condition =
        _readString(elseBlock['else_condition'])?.toLowerCase() ?? 'is';
    final actual = _readTriggerValue(parentBlock, values) ?? '';
    switch (condition) {
      case 'is':
      case 'equals':
      case 'equal':
        return _equals(actual, elseValue);
      case 'is_not':
      case 'not':
        return !_equals(actual, elseValue);
      default:
        return _equals(actual, elseValue);
    }
  }

  static String? _readTriggerValue(
    Map<String, dynamic> block,
    Map<String, String?> values,
  ) {
    final apiName = _readString(block['api_name']);
    if (apiName != null) {
      final byApi = values['api:$apiName'];
      if (byApi != null) return byApi;
    }

    final fieldApiName = _readString(block['field_api_name']);
    if (fieldApiName != null && fieldApiName.startsWith('__field__:')) {
      final id = int.tryParse(fieldApiName.substring('__field__:'.length));
      if (id != null) {
        final byId = values['id:$id'];
        if (byId != null) return byId;
      }
    }

    final fieldId = block['field_id'];
    if (fieldId != null) {
      final idKey = fieldId.toString().trim();
      final byFid = values['fid:$idKey'];
      if (byFid != null) return byFid;
      final parsedId = int.tryParse(idKey);
      if (parsedId != null) {
        final byId = values['id:$parsedId'];
        if (byId != null) return byId;
      }
    }

    final fId = _readString(block['f_id']);
    if (fId != null) {
      final byFid = values['fid:$fId'];
      if (byFid != null) return byFid;
    }

    final fieldUid = _readString(block['field_uid']);
    if (fieldUid != null) {
      final byFid = values['fid:$fieldUid'];
      if (byFid != null) return byFid;
      final parsedId = int.tryParse(fieldUid);
      if (parsedId != null) {
        final byId = values['id:$parsedId'];
        if (byId != null) return byId;
      }
    }

    return apiName != null ? values['api:$apiName'] : null;
  }

  static int? _resolveSectionId(
    Map<String, dynamic> action,
    List<FormMetadataSection> sections,
  ) {
    final knownIds = {for (final section in sections) section.id};

    // Prefer stable metadata ids from the rule builder (`__section__:51`).
    final fieldApiName = _readString(action['field_api_name']);
    if (fieldApiName != null && fieldApiName.startsWith('__section__:')) {
      final id = int.tryParse(fieldApiName.substring('__section__:'.length));
      if (id != null && (knownIds.isEmpty || knownIds.contains(id))) return id;
    }

    final apiName = _readString(action['api_name']);
    if (apiName != null && sections.isNotEmpty) {
      for (final section in sections) {
        if (section.name.trim().toLowerCase() == apiName.trim().toLowerCase()) {
          return section.id;
        }
      }
    }

    final sid = _readString(action['s_id']) ??
        _readString(action['section_uid']) ??
        _readString(action['section_id']);
    if (sid != null && sections.isNotEmpty) {
      for (final section in sections) {
        if (section.sid == sid) return section.id;
        if (section.id.toString() == sid) return section.id;
      }
    }

    // Only accept numeric ids that exist on this form (ignore template UIDs).
    for (final candidate in [
      action['section_id'],
      action['section_uid'],
      action['s_id'],
    ]) {
      final parsed = _readInt(candidate);
      if (parsed != null && knownIds.contains(parsed)) return parsed;
    }

    return null;
  }

  static int? _resolveFieldId(
    Map<String, dynamic> action,
    List<FormMetadataSection> sections,
  ) {
    final knownIds = {
      for (final section in sections)
        for (final field in section.fields) field.id,
    };

    // Prefer stable metadata ids (`__field__:273`). Template UIDs in
    // `field_id` / `f_id` are large ints that are NOT form field ids.
    final fieldApiName = _readString(action['field_api_name']);
    if (fieldApiName != null && fieldApiName.startsWith('__field__:')) {
      final id = int.tryParse(fieldApiName.substring('__field__:'.length));
      if (id != null && (knownIds.isEmpty || knownIds.contains(id))) return id;
    }

    final apiName = _readString(action['api_name']);
    if (apiName != null && sections.isNotEmpty) {
      for (final section in sections) {
        for (final field in section.fields) {
          if (field.apiName.trim().toLowerCase() ==
              apiName.trim().toLowerCase()) {
            return field.id;
          }
        }
      }
    }

    for (final candidate in [
      action['field_id'],
      action['field_uid'],
      action['f_id'],
    ]) {
      final asString = _readString(candidate);
      if (asString == null) continue;
      for (final section in sections) {
        for (final field in section.fields) {
          if (field.fid == asString) return field.id;
          if (field.id.toString() == asString) return field.id;
        }
      }
      final parsed = int.tryParse(asString);
      if (parsed != null && knownIds.contains(parsed)) return parsed;
    }

    return null;
  }

  static _FormRuleAction _readAction(Map<String, dynamic> action) {
    final raw = _readString(action['action'])?.toLowerCase();
    if (raw == 'hide') return _FormRuleAction.hide;
    return _FormRuleAction.show;
  }

  static _FormRuleTarget _readTargetType(Map<String, dynamic> action) {
    final raw = _readString(action['target_type'])?.toLowerCase();
    if (raw == 'section') return _FormRuleTarget.section;
    if (raw == 'field') return _FormRuleTarget.field;
    return _FormRuleTarget.unknown;
  }

  static bool _equals(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }
}

enum _FormRuleAction { show, hide }

enum _FormRuleTarget { field, section, unknown }

/// Builds the value map consumed by [FormVisibilityEngine.evaluate].
Map<String, String?> buildFormVisibilityValues({
  required List<FormMetadataSection> sections,
  required String? Function(FormMetadataField field) readValue,
}) {
  final values = <String, String?>{};
  for (final section in sections) {
    for (final field in section.fields) {
      final current = readValue(field);
      values['api:${field.apiName}'] = current;
      values['id:${field.id}'] = current;
      if (field.fid != null && field.fid!.isNotEmpty) {
        values['fid:${field.fid}'] = current;
      }
    }
  }
  return values;
}
