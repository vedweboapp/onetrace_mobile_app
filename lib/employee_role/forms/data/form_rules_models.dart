/// Models for OneTrace dynamic form rules (`data.rules` / rules API).
library;

import 'package:flutter/foundation.dart';

enum RuleAction { show, hide, require, disable }

enum RuleCondition {
  isCondition,
  isNot,
  isEmpty,
  isNotEmpty,
  endsWith,
  isAnyOneOf,
  isNoneOf,
}

enum RuleTargetType { field, section, unknown }

@immutable
final class FormRuleOutput {
  const FormRuleOutput({
    required this.action,
    this.targetType = RuleTargetType.unknown,
    this.fieldApiName,
    this.fId,
    this.sId,
    this.apiName,
    this.fieldUid,
    this.sectionUid,
  });

  final RuleAction action;
  final RuleTargetType targetType;
  final String? fieldApiName;
  final dynamic fId;
  final dynamic sId;
  final String? apiName;
  final String? fieldUid;
  final String? sectionUid;

  factory FormRuleOutput.fromJson(Map<String, dynamic> json) {
    return FormRuleOutput(
      action: parseRuleAction(json['action']),
      targetType: parseRuleTargetType(json['target_type']),
      fieldApiName: _string(json['field_api_name']),
      fId: json['f_id'] ?? json['field_id'],
      sId: json['s_id'] ?? json['section_id'],
      apiName: _string(json['api_name']),
      fieldUid: _string(json['field_uid']) ?? _string(json['u_id']),
      sectionUid: _string(json['section_uid']),
    );
  }
}

@immutable
final class ElseBlock {
  const ElseBlock({
    required this.uid,
    required this.elseOutputFields,
    this.elseCondition,
    this.elseValue,
  });

  final String uid;
  final RuleCondition? elseCondition;
  final dynamic elseValue;
  final List<FormRuleOutput> elseOutputFields;

  factory ElseBlock.fromJson(Map<String, dynamic> json) {
    return ElseBlock(
      uid: _string(json['_uid']) ?? '',
      elseCondition: parseRuleCondition(json['else_condition']),
      elseValue: json['else_value'],
      elseOutputFields: _mapOutputs(json['else_output_fields']),
    );
  }
}

@immutable
final class FormRuleBlock {
  const FormRuleBlock({
    required this.uid,
    required this.condition,
    required this.outputFields,
    required this.elseBlocks,
    this.fieldApiName,
    this.fId,
    this.apiName,
    this.fieldUid,
    this.value,
  });

  final String uid;
  final String? fieldApiName;
  final dynamic fId;
  final String? apiName;
  final String? fieldUid;
  final RuleCondition condition;
  final dynamic value;
  final List<FormRuleOutput> outputFields;
  final List<ElseBlock> elseBlocks;

  factory FormRuleBlock.fromJson(Map<String, dynamic> json) {
    return FormRuleBlock(
      uid: _string(json['_uid']) ?? '',
      fieldApiName: _string(json['field_api_name']),
      fId: json['f_id'] ?? json['field_id'],
      apiName: _string(json['api_name']),
      fieldUid: _string(json['field_uid']) ?? _string(json['u_id']),
      condition:
          parseRuleCondition(json['condition']) ?? RuleCondition.isCondition,
      value: json['value'],
      outputFields: _mapOutputs(json['output_fields']),
      elseBlocks: (json['else_blocks'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ElseBlock.fromJson(
              Map<String, dynamic>.from(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

@immutable
final class FormRule {
  const FormRule({
    required this.uid,
    required this.name,
    required this.sequence,
    required this.ruleType,
    required this.blocks,
  });

  final String uid;
  final String name;
  final int sequence;
  final String ruleType;
  final List<FormRuleBlock> blocks;

  factory FormRule.fromJson(Map<String, dynamic> json) {
    final logic = json['logic'];
    final rawBlocks = logic is Map
        ? logic['blocks']
        : json['blocks'];
    return FormRule(
      uid: _string(json['_uid']) ?? json['id']?.toString() ?? '',
      name: _string(json['name']) ?? '',
      sequence: _int(json['sequence']) ??
          (logic is Map ? _int(logic['sequence']) : null) ??
          0,
      ruleType: _string(json['rule_type']) ??
          (logic is Map ? _string(logic['rule_type']) : null) ??
          'advanced',
      blocks: (rawBlocks as List? ?? const [])
          .whereType<Map>()
          .map(
            (b) => FormRuleBlock.fromJson(
              Map<String, dynamic>.from(
                b.map((k, v) => MapEntry(k.toString(), v)),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Parses API / metadata rule rows into typed [FormRule]s.
List<FormRule> parseFormRules(List<Map<String, dynamic>> rawRules) {
  return rawRules
      .map(FormRule.fromJson)
      .where((rule) => rule.blocks.isNotEmpty)
      .toList(growable: false)
    ..sort((a, b) => a.sequence.compareTo(b.sequence));
}

RuleAction parseRuleAction(dynamic raw) {
  switch (_string(raw)?.toLowerCase()) {
    case 'hide':
      return RuleAction.hide;
    case 'require':
      return RuleAction.require;
    case 'disable':
      return RuleAction.disable;
    case 'show':
    default:
      return RuleAction.show;
  }
}

RuleCondition? parseRuleCondition(dynamic raw) {
  switch (_string(raw)?.toLowerCase()) {
    case 'is':
    case 'equals':
    case 'equal':
    case '==':
      return RuleCondition.isCondition;
    case 'is_not':
    case 'not':
    case '!=':
      return RuleCondition.isNot;
    case 'is_empty':
    case 'empty':
      return RuleCondition.isEmpty;
    case 'is_not_empty':
    case 'not_empty':
      return RuleCondition.isNotEmpty;
    case 'ends_with':
      return RuleCondition.endsWith;
    case 'is_any_one_of':
      return RuleCondition.isAnyOneOf;
    case 'is_none_of':
      return RuleCondition.isNoneOf;
    default:
      return null;
  }
}

RuleTargetType parseRuleTargetType(dynamic raw) {
  switch (_string(raw)?.toLowerCase()) {
    case 'section':
      return RuleTargetType.section;
    case 'field':
      return RuleTargetType.field;
    default:
      return RuleTargetType.unknown;
  }
}

List<FormRuleOutput> _mapOutputs(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (e) => FormRuleOutput.fromJson(
          Map<String, dynamic>.from(
            e.map((k, v) => MapEntry(k.toString(), v)),
          ),
        ),
      )
      .toList(growable: false);
}

String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}
