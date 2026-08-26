/// OneTrace form rules engine — visibility / required / disabled evaluation.
library;

import 'package:flutter/foundation.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';
import 'package:red5/employee_role/forms/data/form_rules_models.dart';

@immutable
final class FieldRuleState {
  const FieldRuleState({
    this.visible = true,
    this.required = false,
    this.disabled = false,
  });

  final bool visible;
  final bool required;
  final bool disabled;

  FieldRuleState copyWith({
    bool? visible,
    bool? required,
    bool? disabled,
  }) {
    return FieldRuleState(
      visible: visible ?? this.visible,
      required: required ?? this.required,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldRuleState &&
          visible == other.visible &&
          required == other.required &&
          disabled == other.disabled;

  @override
  int get hashCode => Object.hash(visible, required, disabled);
}

@immutable
final class FormRulesSnapshot {
  const FormRulesSnapshot({
    required this.fieldStates,
    required this.sectionVisible,
  });

  final Map<int, FieldRuleState> fieldStates;
  final Map<int, bool> sectionVisible;

  bool isSectionVisible(FormMetadataSection section) =>
      sectionVisible[section.id] ?? true;

  bool isFieldVisible(FormMetadataField field) =>
      fieldStates[field.id]?.visible ?? true;

  bool isFieldRequired(FormMetadataField field) =>
      field.isRequired || (fieldStates[field.id]?.required ?? false);

  bool isFieldDisabled(FormMetadataField field) =>
      field.isReadonly || (fieldStates[field.id]?.disabled ?? false);

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

/// Evaluates metadata / API form rules per OneTrace architecture.
final class FormRulesEngine {
  FormRulesEngine({
    required List<FormMetadataSection> sections,
    required List<Map<String, dynamic>> rules,
  })  : _sections = sections,
        _rules = parseFormRules(rules),
        _fieldById = {
          for (final section in sections)
            for (final field in section.fields) field.id: field,
        },
        _sectionById = {
          for (final section in sections) section.id: section,
        },
        _fieldSectionId = {
          for (final section in sections)
            for (final field in section.fields) field.id: section.id,
        };

  final List<FormMetadataSection> _sections;
  final List<FormRule> _rules;
  final Map<int, FormMetadataField> _fieldById;
  final Map<int, FormMetadataSection> _sectionById;
  final Map<int, int> _fieldSectionId;

  bool get hasRules => _rules.isNotEmpty;

  FormRulesSnapshot evaluate(Map<String, dynamic> formValues) {
    if (_rules.isEmpty) {
      return FormRulesSnapshot(
        fieldStates: {
          for (final id in _fieldById.keys) id: const FieldRuleState(),
        },
        sectionVisible: {
          for (final id in _sectionById.keys) id: true,
        },
      );
    }

    final baseFields = <int, FieldRuleState>{
      for (final id in _fieldById.keys) id: const FieldRuleState(),
    };
    final baseSections = <int, bool>{
      for (final id in _sectionById.keys) id: true,
    };

    // Phase 1: show-targets default to hidden.
    for (final rule in _rules) {
      for (final block in rule.blocks) {
        for (final output in [
          ...block.outputFields,
          ...block.elseBlocks.expand((e) => e.elseOutputFields),
        ]) {
          if (output.action != RuleAction.show) continue;
          final target = _resolveTarget(output);
          if (target == null) continue;
          if (target.isSection) {
            baseSections[target.id] = false;
          } else {
            baseFields[target.id] = baseFields[target.id]!.copyWith(
              visible: false,
            );
          }
        }
      }
    }

    var currentFields = _cloneFields(baseFields);
    var currentSections = Map<int, bool>.from(baseSections);

    const maxPasses = 10;
    for (var pass = 0; pass < maxPasses; pass++) {
      final nextFields = _cloneFields(baseFields);
      final nextSections = Map<int, bool>.from(baseSections);

      for (final rule in _rules) {
        for (final block in rule.blocks) {
          final triggerId = _resolveTriggerFieldId(block);
          if (triggerId != null) {
            final triggerVisible = nextFields[triggerId]?.visible ?? true;
            final sectionId = _fieldSectionId[triggerId];
            final sectionVisible =
                sectionId == null ? true : (nextSections[sectionId] ?? true);
            if (!triggerVisible || !sectionVisible) continue;
          }

          final triggerValue = getTriggerValue(
            block: block,
            formValues: formValues,
          );
          final ifMatched = evaluateCondition(
            triggerValue,
            block.condition,
            block.value,
          );

          if (ifMatched) {
            _applyOutputs(
              block.outputFields,
              fields: nextFields,
              sections: nextSections,
            );
          } else {
            for (final elseBlock in block.elseBlocks) {
              var fires = true;
              if (elseBlock.elseCondition != null) {
                fires = evaluateCondition(
                  triggerValue,
                  elseBlock.elseCondition!,
                  elseBlock.elseValue,
                );
              }
              if (!fires) continue;
              _applyOutputs(
                elseBlock.elseOutputFields,
                fields: nextFields,
                sections: nextSections,
              );
            }
          }
        }
      }

      if (_mapsEqual(currentFields, nextFields) &&
          mapEquals(currentSections, nextSections)) {
        currentFields = nextFields;
        currentSections = nextSections;
        break;
      }
      currentFields = nextFields;
      currentSections = nextSections;
    }

    return FormRulesSnapshot(
      fieldStates: currentFields,
      sectionVisible: currentSections,
    );
  }

  void _applyOutputs(
    List<FormRuleOutput> outputs, {
    required Map<int, FieldRuleState> fields,
    required Map<int, bool> sections,
  }) {
    for (final output in outputs) {
      final target = _resolveTarget(output);
      if (target == null) continue;
      if (target.isSection) {
        switch (output.action) {
          case RuleAction.show:
            sections[target.id] = true;
          case RuleAction.hide:
            sections[target.id] = false;
          case RuleAction.require:
          case RuleAction.disable:
            break;
        }
        continue;
      }

      final state = fields[target.id] ?? const FieldRuleState();
      switch (output.action) {
        case RuleAction.show:
          fields[target.id] = state.copyWith(visible: true);
        case RuleAction.hide:
          fields[target.id] = state.copyWith(visible: false);
        case RuleAction.require:
          fields[target.id] = state.copyWith(required: true);
        case RuleAction.disable:
          fields[target.id] = state.copyWith(disabled: true);
      }
    }
  }

  /// Alias lookup order: f_id → field_api_name → api_name → __field__:<id>.
  static dynamic getTriggerValue({
    required FormRuleBlock block,
    required Map<String, dynamic> formValues,
  }) {
    for (final alias in _triggerAliases(block)) {
      if (!formValues.containsKey(alias)) continue;
      final value = formValues[alias];
      if (value != null) return value;
    }
    // Allow explicit empty string / empty list as a present value.
    for (final alias in _triggerAliases(block)) {
      if (formValues.containsKey(alias)) return formValues[alias];
    }
    return null;
  }

  static List<String> _triggerAliases(FormRuleBlock block) {
    final aliases = <String>[];

    void add(String? value) {
      if (value == null || value.isEmpty) return;
      if (!aliases.contains(value)) aliases.add(value);
    }

    // Priority 1: f_id / field_id
    if (block.fId != null && block.fId.toString().trim().isNotEmpty) {
      final idStr = block.fId.toString().trim();
      add(idStr);
      add('__field__:$idStr');
      add('id:$idStr');
      add('fid:$idStr');
    }

    // Priority 2: field_api_name
    final fieldApiName = block.fieldApiName;
    if (fieldApiName != null && fieldApiName.isNotEmpty) {
      add(fieldApiName);
      if (fieldApiName.startsWith('__field__:')) {
        final bare = fieldApiName.substring('__field__:'.length);
        add(bare);
        add('id:$bare');
      } else {
        add('__field__:$fieldApiName');
      }
    }

    // Priority 3: api_name
    final apiName = block.apiName;
    if (apiName != null && apiName.isNotEmpty) {
      add(apiName);
      add('api:$apiName');
      add('__field__:$apiName');
    }

    // Priority 4: field_uid (drafts)
    final fieldUid = block.fieldUid;
    if (fieldUid != null && fieldUid.isNotEmpty) {
      add(fieldUid);
      add('fid:$fieldUid');
      add('__field__:$fieldUid');
    }

    return aliases;
  }

  static bool evaluateCondition(
    dynamic fieldValue,
    RuleCondition condition,
    dynamic ruleValue,
  ) {
    final fieldVals = _normalizeValue(fieldValue);
    final ruleVals = _normalizeValue(ruleValue);

    switch (condition) {
      case RuleCondition.isEmpty:
        return fieldVals.isEmpty;
      case RuleCondition.isNotEmpty:
        return fieldVals.isNotEmpty;
      case RuleCondition.isCondition:
      case RuleCondition.isAnyOneOf:
        return fieldVals.any(ruleVals.contains);
      case RuleCondition.isNot:
      case RuleCondition.isNoneOf:
        return !fieldVals.any(ruleVals.contains);
      case RuleCondition.endsWith:
        final raw = fieldValue?.toString().toLowerCase() ?? '';
        return ruleVals.any(raw.endsWith);
    }
  }

  static List<String> _normalizeValue(dynamic val) {
    if (val == null) return const [];
    if (val is List) {
      return val
          .map((v) => v.toString().trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    final str = val.toString().trim().toLowerCase();
    if (str.isEmpty) return const [];
    if (str.contains(',')) {
      return str
          .split(',')
          .map((v) => v.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    return [str];
  }

  int? _resolveTriggerFieldId(FormRuleBlock block) {
    // Prefer stable __field__:<dbId> / api_name over template UIDs in f_id.
    final fieldApiName = block.fieldApiName;
    if (fieldApiName != null && fieldApiName.startsWith('__field__:')) {
      final id = int.tryParse(fieldApiName.substring('__field__:'.length));
      if (id != null && _fieldById.containsKey(id)) return id;
    }

    final apiName = block.apiName;
    if (apiName != null) {
      for (final field in _fieldById.values) {
        if (field.apiName.trim().toLowerCase() == apiName.trim().toLowerCase()) {
          return field.id;
        }
      }
    }

    for (final candidate in [block.fId, block.fieldUid]) {
      final id = _matchKnownFieldId(candidate);
      if (id != null) return id;
    }

    if (fieldApiName != null && !fieldApiName.startsWith('__field__:')) {
      for (final field in _fieldById.values) {
        if (field.apiName.trim().toLowerCase() ==
            fieldApiName.trim().toLowerCase()) {
          return field.id;
        }
      }
    }

    return null;
  }

  _ResolvedTarget? _resolveTarget(FormRuleOutput output) {
    var targetType = output.targetType;
    if (targetType == RuleTargetType.unknown) {
      final fieldApiName = output.fieldApiName;
      if (fieldApiName != null && fieldApiName.startsWith('__section__:')) {
        targetType = RuleTargetType.section;
      } else if (fieldApiName != null &&
          fieldApiName.startsWith('__field__:')) {
        targetType = RuleTargetType.field;
      } else if (output.sId != null && output.fId == null) {
        targetType = RuleTargetType.section;
      } else {
        targetType = RuleTargetType.field;
      }
    }

    if (targetType == RuleTargetType.section) {
      final id = _resolveSectionId(output);
      if (id == null) return null;
      return _ResolvedTarget(id: id, isSection: true);
    }

    final id = _resolveFieldId(output);
    if (id == null) return null;
    return _ResolvedTarget(id: id, isSection: false);
  }

  int? _resolveSectionId(FormRuleOutput output) {
    final fieldApiName = output.fieldApiName;
    if (fieldApiName != null && fieldApiName.startsWith('__section__:')) {
      final id = int.tryParse(fieldApiName.substring('__section__:'.length));
      if (id != null && _sectionById.containsKey(id)) return id;
    }

    final apiName = output.apiName;
    if (apiName != null) {
      for (final section in _sections) {
        if (section.name.trim().toLowerCase() == apiName.trim().toLowerCase()) {
          return section.id;
        }
      }
    }

    for (final candidate in [output.sId, output.sectionUid]) {
      final asString = candidate?.toString().trim();
      if (asString == null || asString.isEmpty) continue;
      for (final section in _sections) {
        if (section.sid == asString) return section.id;
        if (section.id.toString() == asString) return section.id;
      }
      final parsed = int.tryParse(asString);
      if (parsed != null && _sectionById.containsKey(parsed)) return parsed;
    }

    return null;
  }

  int? _resolveFieldId(FormRuleOutput output) {
    final fieldApiName = output.fieldApiName;
    if (fieldApiName != null && fieldApiName.startsWith('__field__:')) {
      final id = int.tryParse(fieldApiName.substring('__field__:'.length));
      if (id != null && _fieldById.containsKey(id)) return id;
    }

    final apiName = output.apiName;
    if (apiName != null) {
      for (final field in _fieldById.values) {
        if (field.apiName.trim().toLowerCase() == apiName.trim().toLowerCase()) {
          return field.id;
        }
      }
    }

    for (final candidate in [output.fId, output.fieldUid]) {
      final id = _matchKnownFieldId(candidate);
      if (id != null) return id;
    }

    if (fieldApiName != null && !fieldApiName.startsWith('__')) {
      for (final field in _fieldById.values) {
        if (field.apiName.trim().toLowerCase() ==
            fieldApiName.trim().toLowerCase()) {
          return field.id;
        }
      }
    }

    return null;
  }

  int? _matchKnownFieldId(dynamic candidate) {
    if (candidate == null) return null;
    final asString = candidate.toString().trim();
    if (asString.isEmpty) return null;
    for (final field in _fieldById.values) {
      if (field.fid == asString) return field.id;
      if (field.id.toString() == asString) return field.id;
    }
    final parsed = int.tryParse(asString);
    if (parsed != null && _fieldById.containsKey(parsed)) return parsed;
    return null;
  }

  static Map<int, FieldRuleState> _cloneFields(Map<int, FieldRuleState> source) {
    return {
      for (final entry in source.entries) entry.key: entry.value,
    };
  }

  static bool _mapsEqual(
    Map<int, FieldRuleState> a,
    Map<int, FieldRuleState> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

final class _ResolvedTarget {
  const _ResolvedTarget({required this.id, required this.isSection});
  final int id;
  final bool isSection;
}

/// Builds the multi-alias value map consumed by [FormRulesEngine.evaluate].
Map<String, dynamic> buildFormRuleValues({
  required List<FormMetadataSection> sections,
  required dynamic Function(FormMetadataField field) readValue,
}) {
  final values = <String, dynamic>{};
  for (final section in sections) {
    for (final field in section.fields) {
      final current = readValue(field);
      final idStr = field.id.toString();
      values[idStr] = current;
      values['id:$idStr'] = current;
      values['__field__:$idStr'] = current;
      values[field.apiName] = current;
      values['api:${field.apiName}'] = current;
      final fid = field.fid;
      if (fid != null && fid.isNotEmpty) {
        values[fid] = current;
        values['fid:$fid'] = current;
        values['__field__:$fid'] = current;
      }
    }
  }
  return values;
}

/// Backward-compatible alias used by existing form UI / tests.
typedef FormVisibilitySnapshot = FormRulesSnapshot;
typedef FormVisibilityEngine = FormRulesEngine;

/// Legacy helper — prefer [buildFormRuleValues].
Map<String, String?> buildFormVisibilityValues({
  required List<FormMetadataSection> sections,
  required String? Function(FormMetadataField field) readValue,
}) {
  final dynamicValues = buildFormRuleValues(
    sections: sections,
    readValue: readValue,
  );
  return {
    for (final entry in dynamicValues.entries)
      entry.key: entry.value?.toString(),
  };
}
