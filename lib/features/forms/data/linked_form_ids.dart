import 'package:red5/core/network/api_int_parsing.dart';

/// Reads template form ids from job/project payloads (`forms`, `form_ids`, nested rows).
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
      final formId = readApiInt(entry['project_form_id']) ??
          readApiInt(entry['form_id']) ??
          readApiInt(entry['form']) ??
          readApiInt(entry['template_id']) ??
          readApiInt(entry['id']);
      if (formId != null) ids.add(formId);
    }
  }

  return ids.where((id) => id > 0).toList(growable: false);
}

List<int> _readIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map(readApiInt).whereType<int>().toList(growable: false);
}
