import 'package:flutter/material.dart';
import 'package:red5/core/network/api_urls.dart';

/// Drawing hierarchy from `GET /jobs/{id}/` → `data.levels[]`.
@immutable
final class EmployeeJobDrawingLevel {
  const EmployeeJobDrawingLevel({
    required this.id,
    required this.name,
    required this.order,
    required this.drawingFileUrl,
    required this.plots,
    this.plotPayloads = const [],
  });

  final int id;
  final String name;
  final int order;
  final String? drawingFileUrl;
  final List<EmployeeJobDrawingPlot> plots;

  /// Raw API `plots[]` payloads for drawing canvas hydration.
  final List<Map<String, dynamic>> plotPayloads;

  int get pinCount =>
      plots.fold<int>(0, (sum, plot) => sum + plot.pins.length);
}

@immutable
final class EmployeeJobDrawingPlot {
  const EmployeeJobDrawingPlot({
    required this.id,
    required this.name,
    required this.borderColor,
    required this.backgroundColor,
    required this.pins,
  });

  final int id;
  final String name;
  final Color borderColor;
  final Color backgroundColor;
  final List<EmployeeJobDrawingPin> pins;
}

@immutable
final class EmployeeJobPinAttachment {
  const EmployeeJobPinAttachment({
    required this.name,
    required this.url,
    this.id,
    this.contentType,
  });

  final int? id;
  final String name;
  final String url;
  final String? contentType;

  bool get hasUrl => url.trim().isNotEmpty;
}

@immutable
final class EmployeeJobDrawingPin {
  const EmployeeJobDrawingPin({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.xCoordinate,
    required this.yCoordinate,
    required this.statusName,
    required this.statusBackground,
    required this.statusForeground,
    required this.itemName,
    required this.attachmentCount,
    this.attachments = const [],
    this.jobPinId,
    this.projectFormId,
    this.projectFormName,
    this.projectFormSubmissionId,
    this.projectFormSubmissionStatus,
    this.qrCode,
    this.qrCodeId,
    this.qrCodeFieldPresent = false,
    this.levelId,
    this.plotId,
  });

  final int id;
  final String name;
  final String description;
  final String location;
  final double xCoordinate;
  final double yCoordinate;
  final String statusName;
  final Color statusBackground;
  final Color statusForeground;
  final String itemName;
  final int attachmentCount;

  /// Pin-level and item_detail attachments the operative can open.
  final List<EmployeeJobPinAttachment> attachments;

  /// `job_pin_id` from API — used as `job_form_id` when submitting pin forms.
  final int? jobPinId;
  final int? projectFormId;
  final String? projectFormName;
  final int? projectFormSubmissionId;
  final String? projectFormSubmissionStatus;
  final String? qrCode;

  /// Display id from API `qr_code_id` (preferred on pin details).
  final String? qrCodeId;

  /// True when the API payload includes a `qr_code` key (even if null/empty).
  final bool qrCodeFieldPresent;
  final int? levelId;
  final int? plotId;

  bool get hasAttachments =>
      attachments.any((attachment) => attachment.hasUrl);

  bool get hasForm => projectFormId != null && projectFormId! > 0;

  bool get hasQrCode {
    final value = qrCode?.trim() ?? '';
    if (value.isEmpty) return false;
    if (value.toLowerCase() == 'null') return false;
    return true;
  }

  /// Prefer `qr_code_id` for display on pin details.
  String? get displayQrCodeId {
    final idValue = qrCodeId?.trim() ?? '';
    if (idValue.isNotEmpty && idValue.toLowerCase() != 'null') {
      return idValue;
    }
    return null;
  }

  bool get isFormSubmitted {
    if (projectFormSubmissionId != null && projectFormSubmissionId! > 0) {
      return true;
    }
    final status = projectFormSubmissionStatus?.trim().toLowerCase();
    return status == 'submitted' || status == 'complete' || status == 'completed';
  }

  bool get isStatusComplete {
    final normalized = statusName.trim().toLowerCase();
    return normalized.contains('complete') && !normalized.contains('incomplete');
  }

  int? get resolvedJobFormId {
    if (jobPinId != null && jobPinId! > 0) return jobPinId;
    if (id > 0) return id;
    return null;
  }

  String get formKey =>
      hasForm ? '${id}_$projectFormId' : 'pin_$id';

  String get displayLabel {
    final locationLabel = location.trim();
    if (locationLabel.isNotEmpty) return 'Pin $locationLabel';
    if (name.trim().isNotEmpty) return name.trim();
    if (itemName.trim().isNotEmpty) return itemName.trim();
    return 'Pin $id';
  }
}

@immutable
final class EmployeeJobPinFormTask {
  const EmployeeJobPinFormTask({
    required this.pinId,
    required this.formId,
    required this.formName,
    required this.pinLabel,
    required this.levelName,
    required this.plotName,
    this.jobPinId,
    this.submissionId,
  });

  final int pinId;
  final int formId;
  final String formName;
  final String pinLabel;
  final String levelName;
  final String plotName;
  final int? jobPinId;
  final int? submissionId;

  String get key => '${pinId}_$formId';
}

/// Drawing row for operative home / site lists (from `GET /jobs/{id}/` levels).
@immutable
final class EmployeeJobDrawingListItem {
  const EmployeeJobDrawingListItem({
    required this.jobId,
    required this.jobTitle,
    required this.siteName,
    required this.projectName,
    required this.level,
    this.projectId,
  });

  final int jobId;
  final String jobTitle;
  final String siteName;
  final String projectName;
  final EmployeeJobDrawingLevel level;
  final int? projectId;

  String get subtitle {
    final site = siteName.trim();
    final levelLabel = 'Level ${level.order}';
    if (site.isEmpty) return levelLabel;
    return '$site • $levelLabel';
  }

  String get updatedLabel {
    final pinCount = level.pinCount;
    if (pinCount > 0) {
      return '$pinCount pin${pinCount == 1 ? '' : 's'} on drawing';
    }
    return 'Drawing available';
  }
}

/// Reads `drawing_file` from a level payload (string, relative path, or nested map).
String? readDrawingFileFromLevelMap(Map<String, dynamic> map) {
  final raw = map['drawing_file'] ??
      map['drawingFile'] ??
      map['drawing_url'] ??
      map['drawingUrl'] ??
      map['file'];
  return resolveEmployeeDrawingFileUrl(raw);
}

/// Normalizes API drawing paths to an absolute URL the app can download.
String? resolveEmployeeDrawingFileUrl(dynamic raw) {
  if (raw == null) return null;

  if (raw is Map) {
    final nested = Map<String, dynamic>.from(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    for (final key in const ['url', 'file', 'path', 'drawing_file', 'href']) {
      final nestedUrl = resolveEmployeeDrawingFileUrl(nested[key]);
      if (nestedUrl != null && nestedUrl.isNotEmpty) return nestedUrl;
    }
    return null;
  }

  final text = raw.toString().trim();
  if (text.isEmpty) return null;

  final parsed = Uri.tryParse(text);
  if (parsed != null &&
      parsed.hasScheme &&
      (parsed.scheme == 'http' || parsed.scheme == 'https')) {
    return _normalizeDrawingMediaHost(parsed).toString();
  }

  final base = Uri.parse(AppApiUrls.baseUrl);
  final path = text.startsWith('/') ? text : '/$text';
  return base.resolve(path).toString();
}

Uri _normalizeDrawingMediaHost(Uri uri) {
  final base = Uri.parse(AppApiUrls.baseUrl);
  final path = uri.path;
  final isMediaPath = path.contains('/media/') || path.contains('/drawings/');
  if (!isMediaPath || uri.host == base.host) return uri;

  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: path,
    query: uri.hasQuery ? uri.query : null,
  );
}

@immutable
final class EmployeeJobSiteDetail {
  const EmployeeJobSiteDetail({
    required this.id,
    required this.name,
    required this.address,
  });

  final int id;
  final String name;
  final String address;
}

List<EmployeeJobDrawingLevel> parseEmployeeJobDrawingLevels(
  dynamic rawLevels,
) {
  if (rawLevels is! List) return const [];

  final levels = <EmployeeJobDrawingLevel>[];
  for (final row in rawLevels) {
    if (row is! Map) continue;
    final map = Map<String, dynamic>.from(
      row.map((k, v) => MapEntry(k.toString(), v)),
    );
    final id = _readInt(map['id']);
    if (id == null) continue;

    final plotsRaw = map['plots'];
    final plots = <EmployeeJobDrawingPlot>[];
    final plotPayloads = <Map<String, dynamic>>[];
    if (plotsRaw is List) {
      for (final plotRow in plotsRaw) {
        if (plotRow is! Map) continue;
        final plotMap = Map<String, dynamic>.from(
          plotRow.map((k, v) => MapEntry(k.toString(), v)),
        );
        plotPayloads.add(plotMap);
        final plot = _parsePlot(plotMap, levelId: id);
        if (plot != null) plots.add(plot);
      }
    }

    levels.add(
      EmployeeJobDrawingLevel(
        id: id,
        name: map['name']?.toString().trim().isNotEmpty == true
            ? map['name'].toString().trim()
            : 'Level $id',
        order: _readInt(map['order']) ?? 0,
        drawingFileUrl: readDrawingFileFromLevelMap(map),
        plots: plots,
        plotPayloads: plotPayloads,
      ),
    );
  }

  levels.sort((a, b) {
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) return byOrder;
    return a.name.compareTo(b.name);
  });
  return levels;
}

EmployeeJobDrawingPlot? _parsePlot(
  Map<String, dynamic> map, {
  required int levelId,
}) {
  final id = _readInt(map['id']);
  if (id == null) return null;

  final pinsRaw = map['pins'];
  final pins = <EmployeeJobDrawingPin>[];
  if (pinsRaw is List) {
    for (final pinRow in pinsRaw) {
      if (pinRow is! Map) continue;
      final pin = _parsePin(
        Map<String, dynamic>.from(
          pinRow.map((k, v) => MapEntry(k.toString(), v)),
        ),
        levelId: levelId,
        plotId: id,
      );
      if (pin != null) pins.add(pin);
    }
  }

  return EmployeeJobDrawingPlot(
    id: id,
    name: map['name']?.toString().trim().isNotEmpty == true
        ? map['name'].toString().trim()
        : 'Plot $id',
    borderColor: _parseHexColor(map['plot_border'], fallback: const Color(0xFF7C3AED)),
    backgroundColor: _parseHexColor(
      map['plot_bg'],
      fallback: const Color(0x0D7C3AED),
    ),
    pins: pins,
  );
}

EmployeeJobDrawingPin? _parsePin(
  Map<String, dynamic> map, {
  required int levelId,
  required int plotId,
}) {
  final id = _readInt(map['id']);
  if (id == null) return null;

  // Project jobs nest under `project_form`; service-style links use
  // `dynamic_form` / `dynamic_form_id`.
  final nestedForm = map['project_form'] ?? map['dynamic_form'] ?? map['form'];
  int? projectFormId = _readInt(map['dynamic_form_id']) ??
      _readInt(map['project_form_id']) ??
      _readInt(map['form_id']);
  String? projectFormName;
  int? projectFormSubmissionId;
  String? projectFormSubmissionStatus;
  if (nestedForm is Map) {
    final formMap = Map<String, dynamic>.from(
      nestedForm.map((k, v) => MapEntry(k.toString(), v)),
    );
    projectFormId ??= _readInt(formMap['id']) ??
        _readInt(formMap['dynamic_form_id']) ??
        _readInt(formMap['project_form_id']);
    projectFormName = formMap['name']?.toString().trim();
    projectFormSubmissionId = _readInt(formMap['submission_id']);
    projectFormSubmissionStatus = formMap['submission_status']?.toString();
  }

  final statusDetail = map['status_detail'];
  var statusName = 'To Do';
  var statusBg = const Color(0xFFE5E7EB);
  var statusFg = const Color(0xFF111827);
  if (statusDetail is Map) {
    final statusMap = Map<String, dynamic>.from(
      statusDetail.map((k, v) => MapEntry(k.toString(), v)),
    );
    statusName = statusMap['status_name']?.toString().trim().isNotEmpty == true
        ? statusMap['status_name'].toString().trim()
        : statusName;
    statusBg = _parseHexColor(statusMap['bg_colour'], fallback: statusBg);
    statusFg = _parseHexColor(statusMap['text_colour'], fallback: statusFg);
  }

  final itemDetail = map['item_detail'];
  var itemName = '';
  Map<String, dynamic>? itemDetailMap;
  if (itemDetail is Map) {
    itemDetailMap = Map<String, dynamic>.from(
      itemDetail.map((k, v) => MapEntry(k.toString(), v)),
    );
    itemName = itemDetailMap['name']?.toString().trim() ?? '';
  }

  final attachments = parseEmployeeJobPinAttachments(
    pinAttachments: map['attachments'],
    itemDetailAttachments: itemDetailMap?['attachments'],
  );

  final hasQrField = map.containsKey('qr_code') ||
      map.containsKey('qr_code_id');
  final rawQr = map['qr_code'];
  String? qrCode;
  if (rawQr != null) {
    final text = rawQr.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      qrCode = text;
    }
  }

  String? qrCodeId;
  final rawQrId = map['qr_code_id'];
  if (rawQrId != null) {
    final text = rawQrId.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      qrCodeId = text;
    }
  }
  if (qrCodeId == null && rawQr is Map) {
    final nested = Map<String, dynamic>.from(
      rawQr.map((k, v) => MapEntry(k.toString(), v)),
    );
    final nestedId = nested['qr_code_id'] ?? nested['code'] ?? nested['id'];
    if (nestedId != null) {
      final text = nestedId.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        qrCodeId = text;
      }
    }
  }

  return EmployeeJobDrawingPin(
    id: id,
    name: map['description']?.toString().trim() ?? '',
    description: map['description']?.toString().trim() ?? '',
    location: map['location']?.toString().trim() ?? '',
    xCoordinate: _readDouble(map['x_coordinate']) ?? 0,
    yCoordinate: _readDouble(map['y_coordinate']) ?? 0,
    statusName: statusName.toUpperCase(),
    statusBackground: statusBg,
    statusForeground: statusFg,
    itemName: itemName,
    attachmentCount: attachments.length,
    attachments: attachments,
    jobPinId: _readInt(map['job_pin_id']),
    projectFormId: projectFormId,
    projectFormName: projectFormName,
    projectFormSubmissionId: projectFormSubmissionId,
    projectFormSubmissionStatus: projectFormSubmissionStatus,
    qrCode: qrCode,
    qrCodeId: qrCodeId,
    qrCodeFieldPresent: hasQrField,
    levelId: levelId,
    plotId: plotId,
  );
}

/// Merges pin `attachments` and `item_detail.attachments`, preferring entries
/// that include a usable file URL.
List<EmployeeJobPinAttachment> parseEmployeeJobPinAttachments({
  dynamic pinAttachments,
  dynamic itemDetailAttachments,
}) {
  final byKey = <String, EmployeeJobPinAttachment>{};

  void addAll(dynamic raw) {
    if (raw is! List) return;
    for (final entry in raw) {
      final parsed = _parsePinAttachmentEntry(entry);
      if (parsed == null || !parsed.hasUrl) continue;
      final key = parsed.id != null
          ? 'id:${parsed.id}'
          : 'url:${parsed.url.trim().toLowerCase()}';
      byKey.putIfAbsent(key, () => parsed);
    }
  }

  addAll(pinAttachments);
  addAll(itemDetailAttachments);
  return byKey.values.toList(growable: false);
}

EmployeeJobPinAttachment? _parsePinAttachmentEntry(dynamic entry) {
  if (entry is! Map) {
    final text = entry?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final resolved = resolveEmployeeDrawingFileUrl(text);
    if (resolved == null || resolved.isEmpty) return null;
    return EmployeeJobPinAttachment(
      name: text.split('/').last,
      url: resolved,
    );
  }

  final map = Map<String, dynamic>.from(
    entry.map((k, v) => MapEntry(k.toString(), v)),
  );
  final rawUrl = map['file'] ??
      map['url'] ??
      map['file_url'] ??
      map['fileUrl'] ??
      map['path'];
  final resolvedUrl = resolveEmployeeDrawingFileUrl(rawUrl);
  if (resolvedUrl == null || resolvedUrl.trim().isEmpty) return null;

  final name = map['file_name']?.toString().trim() ??
      map['filename']?.toString().trim() ??
      map['name']?.toString().trim() ??
      '';
  final resolvedName = name.isNotEmpty
      ? name
      : resolvedUrl.split('/').last;

  return EmployeeJobPinAttachment(
    id: _readInt(map['id']),
    name: resolvedName,
    url: resolvedUrl,
    contentType: map['content_type_value']?.toString().trim() ??
        map['content_type']?.toString().trim(),
  );
}

EmployeeJobSiteDetail? parseEmployeeJobSiteDetail(dynamic rawSite) {
  if (rawSite is! Map) return null;
  final map = Map<String, dynamic>.from(
    rawSite.map((k, v) => MapEntry(k.toString(), v)),
  );
  final id = _readInt(map['id']);
  if (id == null) return null;

  final parts = <String>[
    map['address_line_1']?.toString().trim() ?? '',
    map['address_line_2']?.toString().trim() ?? '',
    map['city']?.toString().trim() ?? '',
    map['state']?.toString().trim() ?? '',
    map['zip_code']?.toString().trim() ?? '',
    map['country']?.toString().trim() ?? '',
  ].where((part) => part.isNotEmpty);

  return EmployeeJobSiteDetail(
    id: id,
    name: map['site_name']?.toString().trim().isNotEmpty == true
        ? map['site_name'].toString().trim()
        : 'Site $id',
    address: parts.join(', '),
  );
}

@immutable
final class EmployeeJobPinListEntry {
  const EmployeeJobPinListEntry({
    required this.pin,
    required this.levelName,
    required this.plotName,
  });

  final EmployeeJobDrawingPin pin;
  final String levelName;
  final String plotName;
}

EmployeeJobDrawingPin? findEmployeeJobPinById(
  List<EmployeeJobDrawingLevel> levels,
  int pinId,
) {
  for (final level in levels) {
    for (final plot in level.plots) {
      for (final pin in plot.pins) {
        if (pin.id == pinId) return pin;
      }
    }
  }
  return null;
}

List<EmployeeJobPinListEntry> collectJobPinEntries(
  List<EmployeeJobDrawingLevel> levels,
) {
  final entries = <EmployeeJobPinListEntry>[];
  for (final level in levels) {
    for (final plot in level.plots) {
      for (final pin in plot.pins) {
        entries.add(
          EmployeeJobPinListEntry(
            pin: pin,
            levelName: level.name,
            plotName: plot.name,
          ),
        );
      }
    }
  }
  return entries;
}

List<EmployeeJobPinFormTask> collectPinFormTasks(
  List<EmployeeJobDrawingLevel> levels,
) {
  final tasks = <EmployeeJobPinFormTask>[];
  for (final level in levels) {
    for (final plot in level.plots) {
      for (final pin in plot.pins) {
        final formId = pin.projectFormId;
        if (formId == null || formId <= 0) continue;
        tasks.add(
          EmployeeJobPinFormTask(
            pinId: pin.id,
            formId: formId,
            formName: pin.projectFormName?.trim().isNotEmpty == true
                ? pin.projectFormName!.trim()
                : 'Form $formId',
            pinLabel: pin.displayLabel,
            levelName: level.name,
            plotName: plot.name,
            jobPinId: pin.jobPinId ?? pin.resolvedJobFormId,
            submissionId: pin.projectFormSubmissionId,
          ),
        );
      }
    }
  }
  return tasks;
}

Color _parseHexColor(dynamic raw, {required Color fallback}) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return fallback;
  var hex = value.replaceFirst('#', '');
  if (hex.length == 8) {
    final a = int.tryParse(hex.substring(6, 8), radix: 16);
    final rgb = int.tryParse(hex.substring(0, 6), radix: 16);
    if (a != null && rgb != null) {
      return Color((a << 24) | rgb);
    }
  }
  if (hex.length == 6) {
    final rgb = int.tryParse(hex, radix: 16);
    if (rgb != null) return Color(0xFF000000 | rgb);
  }
  return fallback;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

double? _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString().trim());
}
