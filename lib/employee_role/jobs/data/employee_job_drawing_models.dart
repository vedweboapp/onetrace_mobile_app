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
    this.projectFormId,
    this.projectFormName,
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
  final int? projectFormId;
  final String? projectFormName;
  final int? levelId;
  final int? plotId;

  bool get hasForm => projectFormId != null && projectFormId! > 0;

  bool get isStatusComplete {
    final normalized = statusName.trim().toLowerCase();
    return normalized.contains('complete') && !normalized.contains('incomplete');
  }

  String get formKey =>
      hasForm ? '${id}_$projectFormId' : 'pin_$id';

  String get displayLabel {
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
    this.jobFormId,
  });

  final int pinId;
  final int formId;
  final String formName;
  final String pinLabel;
  final String levelName;
  final String plotName;
  final int? jobFormId;

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

  final projectForm = map['project_form'];
  int? projectFormId;
  String? projectFormName;
  if (projectForm is Map) {
    final formMap = Map<String, dynamic>.from(
      projectForm.map((k, v) => MapEntry(k.toString(), v)),
    );
    projectFormId = _readInt(formMap['id']);
    projectFormName = formMap['name']?.toString().trim();
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
  if (itemDetail is Map) {
    itemName = itemDetail['name']?.toString().trim() ?? '';
  }

  final attachments = map['attachments'];
  final attachmentCount = attachments is List ? attachments.length : 0;

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
    attachmentCount: attachmentCount,
    projectFormId: projectFormId,
    projectFormName: projectFormName,
    levelId: levelId,
    plotId: plotId,
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

int countIncompleteAssignedPins(List<EmployeeJobDrawingLevel> levels) {
  return collectJobPinEntries(levels)
      .where((entry) => !entry.pin.isStatusComplete)
      .length;
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
            jobFormId: pin.id,
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
