import 'package:red5/core/network/api_int_parsing.dart';

/// Reads template form ids from job/project payloads (`forms`, `form_ids`, nested rows).
///
/// Project jobs often leave top-level `forms` empty and attach forms on
/// `levels[].plots[].pins[].project_form` instead.
List<int> readLinkedTemplateFormIds(Map<String, dynamic> map) {
  final ids = <int>{
    ..._readIntList(map['form_ids']),
    ..._readIntList(map['forms']),
    if (readApiInt(map['form']) != null) readApiInt(map['form'])!,
  };

  final forms = map['forms'];
  if (forms is List) {
    for (final row in forms) {
      if (row is num) {
        ids.add(row.toInt());
        continue;
      }
      if (row is! Map) continue;
      final entry = Map<String, dynamic>.from(
        row.map((k, v) => MapEntry(k.toString(), v)),
      );
      final formId = readApiInt(entry['dynamic_form_id']) ??
          readApiInt(entry['project_form_id']) ??
          readApiInt(entry['form_id']) ??
          readApiInt(entry['form']) ??
          readApiInt(entry['template_id']) ??
          readApiInt(entry['id']);
      if (formId != null) ids.add(formId);
    }
  }

  ids.addAll(readPinProjectFormIds(map['levels']));

  return ids.where((id) => id > 0).toList(growable: false);
}

/// Collects `project_form.id` / `project_form_id` from drawing pins.
List<int> readPinProjectFormIds(dynamic levelsRaw) {
  if (levelsRaw is! List) return const [];
  final ids = <int>{};
  for (final level in levelsRaw) {
    if (level is! Map) continue;
    final levelMap = Map<String, dynamic>.from(
      level.map((k, v) => MapEntry(k.toString(), v)),
    );
    final plots = levelMap['plots'];
    if (plots is! List) continue;
    for (final plot in plots) {
      if (plot is! Map) continue;
      final plotMap = Map<String, dynamic>.from(
        plot.map((k, v) => MapEntry(k.toString(), v)),
      );
      final pins = plotMap['pins'];
      if (pins is! List) continue;
      for (final pin in pins) {
        if (pin is! Map) continue;
        final pinMap = Map<String, dynamic>.from(
          pin.map((k, v) => MapEntry(k.toString(), v)),
        );
        final nested = pinMap['project_form'] ?? pinMap['dynamic_form'];
        int? formId = readApiInt(pinMap['project_form_id']) ??
            readApiInt(pinMap['dynamic_form_id']) ??
            readApiInt(pinMap['form_id']);
        if (nested is Map) {
          final formMap = Map<String, dynamic>.from(
            nested.map((k, v) => MapEntry(k.toString(), v)),
          );
          formId ??= readApiInt(formMap['id']) ??
              readApiInt(formMap['project_form_id']) ??
              readApiInt(formMap['dynamic_form_id']);
        }
        if (formId != null && formId > 0) ids.add(formId);
      }
    }
  }
  return ids.toList(growable: false);
}

List<int> _readIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map(readApiInt).whereType<int>().toList(growable: false);
}
