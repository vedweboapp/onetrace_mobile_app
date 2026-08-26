part of '../drawing_canvas.dart';

String _readStringFromPinMap(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(
    value.map((k, v) => MapEntry(k.toString(), v)),
  );
}

String _readPinProductName(Map<String, dynamic> p) {
  final direct = _readStringFromPinMap(
    p,
    const ['item_name', 'product_name', 'name', 'title'],
  );
  if (direct.isNotEmpty) return direct;
  for (final key in const ['item', 'composite_item', 'item_key']) {
    final nested = _asStringKeyedMap(p[key]);
    if (nested == null) continue;
    final name = _readStringFromPinMap(
      nested,
      const ['item_name', 'name', 'title', 'product_name'],
    );
    if (name.isNotEmpty) return name;
  }
  return '';
}

String _readPinGroupName(Map<String, dynamic> p) {
  final direct = _readStringFromPinMap(
    p,
    const ['group_name', 'group_label'],
  );
  if (direct.isNotEmpty) return direct;
  final nested = _asStringKeyedMap(p['group']);
  if (nested == null) return '';
  return _readStringFromPinMap(
    nested,
    const ['name', 'group_name', 'title', 'label'],
  );
}

String _readPinBlockName(Map<String, dynamic> p, String fallback) {
  final fromPin = _readStringFromPinMap(p, const ['block_name', 'block']);
  return fromPin.isNotEmpty ? fromPin : fallback;
}

String _readPinLevelName(Map<String, dynamic> p, String fallback) {
  final fromPin = _readStringFromPinMap(
    p,
    const ['level_name', 'level', 'level_label'],
  );
  return fromPin.isNotEmpty ? fromPin : fallback;
}

String _readPinPlotName(Map<String, dynamic> p, String plotFallback) {
  final fromPin = _readStringFromPinMap(
    p,
    const ['plot_name', 'zone', 'zone_name', 'plot'],
  );
  return fromPin.isNotEmpty ? fromPin : plotFallback;
}

int? _readPinStatusId(Map<String, dynamic> p) {
  final raw = p['status'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  final nested = _asStringKeyedMap(raw);
  if (nested != null) {
    final id = nested['id'] ?? nested['status_id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse('${id ?? ''}');
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
  return int.tryParse('${raw ?? ''}');
}

String? _readPinStatusName(Map<String, dynamic> p) {
  final nested = _asStringKeyedMap(p['status']);
  if (nested != null) {
    final name = _readStringFromPinMap(
      nested,
      const ['status_name', 'name', 'title', 'label'],
    );
    if (name.isNotEmpty) return name;
  }
  final detail = _asStringKeyedMap(p['status_detail']);
  if (detail != null) {
    final name = _readStringFromPinMap(
      detail,
      const ['status_name', 'name', 'title', 'label'],
    );
    if (name.isNotEmpty) return name;
  }
  final direct = _readStringFromPinMap(
    p,
    const ['status_name', 'status_label'],
  );
  return direct.isEmpty ? null : direct;
}

({Color? bg, Color? fg}) _readPinStatusColors(Map<String, dynamic> p) {
  Map<String, dynamic>? nested = _asStringKeyedMap(p['status_detail']);
  nested ??= _asStringKeyedMap(p['status']);
  if (nested == null) return (bg: null, fg: null);
  return (
    bg: parseHexColor(
      _readStringFromPinMap(nested, const ['bg_colour', 'bg_color', 'colour']),
    ),
    fg: parseHexColor(
      _readStringFromPinMap(
        nested,
        const ['text_colour', 'text_color', 'fg_colour', 'fg_color'],
      ),
    ),
  );
}

String _readPinVariation(Map<String, dynamic> p) {
  final raw = p['variation'];
  if (raw is bool) return raw ? 'Yes' : 'No';
  if (raw is num) return raw != 0 ? 'Yes' : 'No';
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'yes' ||
        normalized == 'true' ||
        normalized == '1' ||
        normalized == 'y') {
      return 'Yes';
    }
    if (normalized == 'no' ||
        normalized == 'false' ||
        normalized == '0' ||
        normalized == 'n') {
      return 'No';
    }
  }
  return 'No';
}

DateTime? _readPinDroppedAt(Map<String, dynamic> p) {
  for (final key in const [
    'dropped_at',
    'created_at',
    'droppedAt',
    'createdAt',
  ]) {
    final raw = p[key];
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();
    }
  }
  return null;
}

int? _readNestedId(dynamic value) {
  if (value is Map) {
    final map = Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
    final idRaw = map['id'] ?? map['item'] ?? map['composite_item_id'];
    if (idRaw is int) return idRaw;
    if (idRaw is num) return idRaw.toInt();
    return int.tryParse('${idRaw ?? ''}');
  }
  return null;
}

String? _readNestedAbbreviation(dynamic value) {
  if (value is! Map) return null;
  final map = Map<String, dynamic>.from(
    value.map((k, v) => MapEntry(k.toString(), v)),
  );
  for (final key in const ['abbreviation', 'short_code', 'code']) {
    final raw = map[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int? _readPinInstallationTypeId(Map<String, dynamic> map) {
  final direct = readInstallationTypeId(map);
  if (direct != null) return direct;
  for (final key in const ['item', 'composite_item', 'item_key']) {
    final nested = _asStringKeyedMap(map[key]);
    if (nested == null) continue;
    final id = readInstallationTypeId(nested);
    if (id != null) return id;
  }
  return null;
}

String _readPinFormName(Map<String, dynamic> map) {
  for (final key in const [
    'form_name',
    'form_title',
    'linked_form_name',
  ]) {
    final raw = map[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  for (final key in const ['form', 'form_id', 'linked_form', 'job_form']) {
    final nested = _asStringKeyedMap(map[key]);
    if (nested == null) continue;
    final name = _readStringFromPinMap(
      nested,
      const ['name', 'title', 'form_name', 'label'],
    );
    if (name.isNotEmpty) return name;
  }
  return '';
}

int? _readPinFormId(Map<String, dynamic> map) {
  for (final key in const [
    'dynamic_form_id',
    'project_form_id',
    'form_id',
    'form',
    'dynamic_form',
    'project_form',
    'linked_form',
    'job_form',
  ]) {
    final raw = map[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final nested = _asStringKeyedMap(raw);
    if (nested != null) {
      for (final idKey in const [
        'id',
        'form_id',
        'job_form_id',
        'dynamic_form_id',
        'project_form_id',
      ]) {
        final idRaw = nested[idKey];
        if (idRaw is int) return idRaw;
        if (idRaw is num) return idRaw.toInt();
        final parsed = int.tryParse('${idRaw ?? ''}');
        if (parsed != null) return parsed;
      }
    }
    final parsed = int.tryParse('${raw ?? ''}');
    if (parsed != null) return parsed;
  }
  return null;
}

List<_PinAttachment> _readPinAttachments(Map<String, dynamic> map) {
  final itemDetail = map['item_detail'];
  dynamic itemDetailAttachments;
  if (itemDetail is Map) {
    itemDetailAttachments = itemDetail['attachments'];
  }

  final parsed = parseEmployeeJobPinAttachments(
    pinAttachments: map['attachments'] ?? map['files'] ?? map['attachment'],
    itemDetailAttachments: itemDetailAttachments,
  );
  if (parsed.isEmpty) return const <_PinAttachment>[];

  return [
    for (final attachment in parsed)
      _PinAttachment(
        name: attachment.name,
        url: attachment.url,
        serverId: attachment.id,
      ),
  ];
}

Map<String, dynamic> _pinAttachmentPayload(_PinAttachment attachment) {
  final payload = <String, dynamic>{'name': attachment.name};
  if (attachment.serverId != null) payload['id'] = attachment.serverId;
  final url = attachment.url?.trim();
  if (url != null && url.isNotEmpty) payload['url'] = url;
  final path = attachment.localPath?.trim();
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (file.existsSync()) {
      payload['file'] = base64Encode(file.readAsBytesSync());
      payload['filename'] = attachment.name;
    }
  }
  return payload;
}
