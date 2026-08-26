import 'package:flutter/foundation.dart';
import 'package:red5/features/forms/data/linked_form_ids.dart';

/// `job_category` query/body values used by `GET/POST /jobs/`.
abstract final class JobApiCategory {
  static const service = 'servicejob';
  static const project = 'projectjob';
}

/// Nested `job_schedule_detail` on both service and project jobs.
@immutable
final class JobScheduleDetail {
  const JobScheduleDetail({
    this.id,
    this.startAt,
    this.endAt,
    this.notes,
    this.recurrence,
    this.recurrenceEndAt,
  });

  final int? id;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? notes;
  final String? recurrence;
  final DateTime? recurrenceEndAt;

  static JobScheduleDetail? tryFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    final id = JobRead._readInt(map['id']);
    final startAt = JobRead._readDate(map['start_at']);
    final endAt = JobRead._readDate(map['end_at']);
    final notes = JobRead._readString(map, const ['notes']);
    final recurrence = JobRead._readString(map, const ['recurrence']);
    final recurrenceEndAt = JobRead._readDate(map['recurrence_end_at']);
    if (id == null &&
        startAt == null &&
        endAt == null &&
        notes == null &&
        recurrence == null &&
        recurrenceEndAt == null) {
      return null;
    }
    return JobScheduleDetail(
      id: id,
      startAt: startAt,
      endAt: endAt,
      notes: notes,
      recurrence: recurrence,
      recurrenceEndAt: recurrenceEndAt,
    );
  }

  Map<String, dynamic>? toWriteMap({
    DateTime? startAtOverride,
    DateTime? endAtOverride,
  }) {
    final start = startAtOverride ?? startAt;
    final end = endAtOverride ?? endAt;
    if (id == null && start == null && end == null) return null;
    return <String, dynamic>{
      if (id != null) 'id': id,
      if (start != null) 'start_at': start.toUtc().toIso8601String(),
      if (end != null) 'end_at': end.toUtc().toIso8601String(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      'recurrence':
          (recurrence == null || recurrence!.trim().isEmpty)
              ? 'none'
              : recurrence!.trim(),
      if (recurrenceEndAt != null)
        'recurrence_end_at': recurrenceEndAt!.toUtc().toIso8601String(),
    };
  }
}

final class JobRead {
  const JobRead({
    required this.id,
    required this.title,
    this.description,
    this.workerName,
    this.pinStatusName,
    this.formsDetails,
    this.jobPinStatus,
    this.jobSource,
    this.startDate,
    this.endDate,
    this.scheduleDetail,
    this.completedAt,
    this.comments,
    this.pinXCoordinate,
    this.pinYCoordinate,
    this.itemName,
    this.sectionName,
    this.plotName,
    this.pinName,
    this.quantity,
    this.sellingPrice,
    this.total,
    this.isVirtualPin = false,
    this.jobMeta = const <String, dynamic>{},
    this.pin,
    this.quotation,
    this.form,
    this.formIds = const [],
    this.assignedWorker,
    this.jobStatus,
    this.client,
    this.project,
    this.site,
    this.projectName,
    this.clientName,
    this.siteName,
    this.organization,
    this.qrCode,
    this.checklists,
    this.jobSerialNumber,
    this.jobCategory,
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String title;
  final String? description;
  final String? workerName;
  final String? pinStatusName;
  final String? formsDetails;
  final String? jobPinStatus;
  final String? jobSource;
  final DateTime? startDate;
  final DateTime? endDate;
  final JobScheduleDetail? scheduleDetail;
  final DateTime? completedAt;
  final String? comments;
  final double? pinXCoordinate;
  final double? pinYCoordinate;
  final String? itemName;
  final String? sectionName;
  final String? plotName;
  final String? pinName;
  final int? quantity;
  final double? sellingPrice;
  final double? total;
  final bool isVirtualPin;
  final Map<String, dynamic> jobMeta;
  final int? pin;
  final int? quotation;
  final int? form;
  final List<int> formIds;
  final int? assignedWorker;
  final int? jobStatus;
  final int? client;
  final int? project;
  final int? site;
  final String? projectName;
  final String? clientName;
  final String? siteName;
  final int? organization;
  final int? qrCode;
  final JobChecklistRead? checklists;
  final String? jobSerialNumber;
  final String? jobCategory;
  final Map<String, dynamic> raw;

  String get displayId {
    final serial = jobSerialNumber?.trim();
    if (serial != null && serial.isNotEmpty) return serial;
    return 'JB-$id';
  }

  bool get isServiceJob {
    final value = (jobCategory ?? '').trim().toLowerCase();
    return value.contains('service');
  }

  bool get isProjectJob {
    final value = (jobCategory ?? '').trim().toLowerCase();
    return value.contains('project');
  }

  String get displayWorker {
    final direct = workerName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final fromMeta = jobMeta['worker_name']?.toString().trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    return assignedWorker == null ? 'Unassigned' : 'Worker $assignedWorker';
  }

  String get displayLocation {
    final site = siteName?.trim();
    if (site != null && site.isNotEmpty) return site;
    final section = sectionName?.trim();
    if (section != null && section.isNotEmpty) return section;
    final plot = plotName?.trim();
    if (plot != null && plot.isNotEmpty) return plot;
    final pinLabel = pinName?.trim();
    if (pinLabel != null && pinLabel.isNotEmpty) return pinLabel;
    return 'Job location';
  }

  String get displayStatus {
    if (completedAt != null) return 'Completed';
    final statusName = jobPinStatus?.trim();
    if (statusName != null && statusName.isNotEmpty) return statusName;
    final pin = pinStatusName?.trim();
    if (pin != null && pin.isNotEmpty) return pin;
    return 'Active';
  }

  static JobRead? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final serial = _readString(map, const ['job_serial_number']);
    final title = _readString(map, const ['title']) ??
        serial ??
        'Untitled Job';
    final schedule = JobScheduleDetail.tryFromMap(map['job_schedule_detail']);
    final jobMeta = _readMap(map['job_meta']);
    var total = _readDouble(map['total']);
    total ??= _readDouble(map['total_earning']);
    total ??= _readDouble(map['total_earnings']);
    total ??= _readDouble(map['job_amount']);
    total ??= _readDouble(map['total_amount']);
    total ??= _readDouble(map['job_total']);
    total ??= _readDouble(map['amount']);
    total ??= _readDouble(jobMeta['total']);
    total ??= _readDouble(jobMeta['total_earning']);
    total ??= _readDouble(jobMeta['total_earnings']);
    total ??= _readDouble(jobMeta['job_amount']);
    total ??= _readDouble(jobMeta['total_amount']);
    total ??= _readDouble(jobMeta['job_total']);
    total ??= _readDouble(jobMeta['amount']);
    final siteName = _readNestedSiteName(map['site']);
    final pinSummary = _firstProjectPinSummary(map['levels']);
    return JobRead(
      id: id,
      title: title,
      description: _readString(map, const ['description']),
      workerName:
          _readString(map, const ['worker_name']) ??
          _readNestedName(map['assigned_worker']) ??
          _readFirstAssignedWorkerName(map['assigned_workers']),
      pinStatusName: _readString(map, const ['pin_status_name']),
      formsDetails: _readString(map, const ['forms_details']),
      jobPinStatus:
          _readString(map, const ['job_pin_status']) ??
          _readNestedStatusName(map['job_status']),
      jobSource: _readString(map, const ['job_source']),
      startDate: schedule?.startAt ?? _readDate(map['start_date']),
      endDate: schedule?.endAt ?? _readDate(map['end_date']),
      scheduleDetail: schedule,
      completedAt: _readDate(map['completed_at']),
      comments: _readString(map, const ['comments']),
      pinXCoordinate:
          _readDouble(map['pin_x_coordinate']) ?? pinSummary.xCoordinate,
      pinYCoordinate:
          _readDouble(map['pin_y_coordinate']) ?? pinSummary.yCoordinate,
      itemName: _readString(map, const ['item_name']) ?? pinSummary.itemName,
      sectionName: siteName ?? _readString(map, const ['section_name']),
      plotName: _readString(map, const ['plot_name']) ?? pinSummary.plotName,
      pinName: _readString(map, const ['pin_name']) ?? pinSummary.pinName,
      quantity: _readInt(map['quantity']) ?? pinSummary.quantity,
      sellingPrice: _readDouble(map['selling_price']),
      total: total,
      isVirtualPin: _readBool(map['is_virtual_pin']) ?? false,
      jobMeta: jobMeta,
      pin: _readInt(map['pin']) ?? pinSummary.pinId,
      quotation: _readInt(map['quotation']),
      form: _readInt(map['form']) ??
          _readFirstFormId(map['forms']) ??
          pinSummary.formId,
      formIds: readLinkedTemplateFormIds(map),
      assignedWorker: _readFkId(map['assigned_worker']) ??
          _readFirstAssignedWorkerId(map['assigned_workers']),
      jobStatus: _readFkId(map['job_status']),
      client: _readFkId(map['client']),
      project: _readFkId(map['project']),
      site: _readFkId(map['site']),
      projectName: _readNestedName(map['project']),
      clientName: _readNestedName(map['client']),
      siteName: siteName,
      organization: _readInt(map['organization']),
      qrCode: _readInt(map['qr_code']) ?? pinSummary.qrCode,
      checklists: JobChecklistRead.tryFromMap(map['checklists']),
      jobSerialNumber: serial,
      jobCategory: _readString(map, const ['job_category']),
      raw: Map<String, dynamic>.from(map),
    );
  }

  static int? _readFkId(dynamic value) {
    if (value is Map) {
      final map = value.map((k, v) => MapEntry(k.toString(), v));
      return _readInt(map['id']);
    }
    return _readInt(value);
  }

  static String? _readNestedName(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
    return _readString(map, const ['name', 'site_name', 'title']);
  }

  static String? _readNestedSiteName(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
    return _readString(map, const ['site_name', 'name', 'title']);
  }

  static String? _readNestedStatusName(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
    return _readString(map, const ['status_name', 'name', 'label']);
  }

  static String? _readFirstAssignedWorkerName(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    for (final row in value) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(
        row.map((k, v) => MapEntry(k.toString(), v)),
      );
      final name = _readString(map, const ['name', 'full_name', 'username']);
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  static int? _readFirstAssignedWorkerId(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    for (final row in value) {
      final id = _readFkId(row);
      if (id != null && id > 0) return id;
    }
    return null;
  }

  static List<int> linkedFormTemplateIds(Map<String, dynamic> map) =>
      readLinkedTemplateFormIds(map);

  static int? _readFirstFormId(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    for (final row in value) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(
        row.map((k, v) => MapEntry(k.toString(), v)),
      );
      final formId =
          _readInt(map['dynamic_form_id']) ??
          _readInt(map['project_form_id']) ??
          _readInt(map['form_id']) ??
          _readInt(map['job_form_id']);
      if (formId != null) return formId;
    }
    return null;
  }

  static _ProjectPinSummary _firstProjectPinSummary(dynamic levelsRaw) {
    if (levelsRaw is! List) return const _ProjectPinSummary();
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
        final plotName = _readString(plotMap, const ['name', 'plot_name']);
        final pins = plotMap['pins'];
        if (pins is! List) continue;
        for (final pin in pins) {
          if (pin is! Map) continue;
          final pinMap = Map<String, dynamic>.from(
            pin.map((k, v) => MapEntry(k.toString(), v)),
          );
          final item = _readMap(pinMap['item_detail']);
          final projectForm = _readMap(pinMap['project_form']);
          final qr = pinMap['qr_code'];
          return _ProjectPinSummary(
            itemName: _readString(item, const ['name', 'item_name']) ??
                _readString(pinMap, const ['item_name', 'name']),
            plotName: plotName,
            pinName: _readString(pinMap, const ['location', 'name', 'pin_name']),
            quantity: _readInt(pinMap['quantity']) ?? _readInt(item['quantity']),
            pinId: _readInt(pinMap['job_pin_id']) ?? _readInt(pinMap['id']),
            formId: _readInt(projectForm['id']) ??
                _readInt(pinMap['project_form_id']),
            qrCode: qr is Map
                ? _readInt(Map<String, dynamic>.from(
                    qr.map((k, v) => MapEntry(k.toString(), v)),
                  )['id'])
                : _readInt(qr),
            xCoordinate: _readDouble(pinMap['x_coordinate']),
            yCoordinate: _readDouble(pinMap['y_coordinate']),
          );
        }
      }
    }
    return const _ProjectPinSummary();
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value == null) return null;
    final cleaned = value.toString().trim().replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString().trim());
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const <String, dynamic>{};
  }
}

final class _ProjectPinSummary {
  const _ProjectPinSummary({
    this.itemName,
    this.plotName,
    this.pinName,
    this.quantity,
    this.pinId,
    this.formId,
    this.qrCode,
    this.xCoordinate,
    this.yCoordinate,
  });

  final String? itemName;
  final String? plotName;
  final String? pinName;
  final int? quantity;
  final int? pinId;
  final int? formId;
  final int? qrCode;
  final double? xCoordinate;
  final double? yCoordinate;
}

@immutable
final class JobChecklistItemRead {
  const JobChecklistItemRead({
    required this.id,
    required this.title,
    required this.sequence,
    required this.isRequired,
    required this.isChecked,
    this.file,
    this.isMarked = false,
    this.concentricPoint = false,
    this.checkedAt,
    this.concentricPointFromApi,
  });

  final int id;
  final String title;
  final int sequence;
  final bool isRequired;
  final bool isChecked;
  final String? file;
  final bool isMarked;
  final bool concentricPoint;
  final DateTime? checkedAt;

  /// `null` when API omitted `concentric_point`; otherwise the explicit flag.
  final bool? concentricPointFromApi;

  bool get hasFile => file != null && file!.trim().isNotEmpty;

  /// Missing `concentric_point` on required items still needs operative confirmation.
  bool get requiresConcentricPoint {
    final explicit = concentricPointFromApi;
    if (explicit != null) return explicit;
    return isRequired;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'sequence': sequence,
    'is_required': isRequired,
    'is_checked': isChecked,
    if (file != null) 'file': file,
    'is_marked': isMarked,
    'concentric_point': concentricPoint,
    if (checkedAt != null) 'checked_at': checkedAt!.toUtc().toIso8601String(),
  };

  /// `PATCH /jobs/{id}/` checklist rows use `checklist_id` (GET returns it as `id`).
  Map<String, dynamic> toWriteJson({
    DateTime? checkedAtOverride,
  }) => <String, dynamic>{
    'checklist_id': id,
    'is_checked': isChecked,
    'concentric_point': isChecked,
    if (isChecked)
      'checked_at': (checkedAtOverride ?? checkedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
  };

  static JobChecklistItemRead? tryFromMap(Map<String, dynamic> map) {
    final id =
        JobRead._readInt(map['checklist_id']) ?? JobRead._readInt(map['id']);
    if (id == null) return null;
    final concentricFromApi = map.containsKey('concentric_point')
        ? (JobRead._readBool(map['concentric_point']) ?? false)
        : null;
    return JobChecklistItemRead(
      id: id,
      title: JobRead._readString(map, const ['title']) ?? 'Checklist item',
      sequence: JobRead._readInt(map['sequence']) ?? 0,
      isRequired: JobRead._readBool(map['is_required']) ?? true,
      isChecked: JobRead._readBool(map['is_checked']) ?? false,
      file: JobRead._readString(map, const ['file']),
      isMarked: JobRead._readBool(map['is_marked']) ?? false,
      concentricPoint: concentricFromApi ?? false,
      concentricPointFromApi: concentricFromApi,
      checkedAt: JobRead._readDate(map['checked_at']),
    );
  }
}

@immutable
final class JobChecklistRead {
  const JobChecklistRead({required this.isMarked, required this.items});

  final bool isMarked;
  final List<JobChecklistItemRead> items;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'is_marked': isMarked,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  /// `PUT /jobs/{id}/` expects `checklists` as a list of item objects.
  List<Map<String, dynamic>> toWriteList({DateTime? checkedAtOverride}) => items
      .map((item) => item.toWriteJson(checkedAtOverride: checkedAtOverride))
      .toList(growable: false);

  static List<JobChecklistItemRead> parseItems(dynamic raw) {
    if (raw is List) {
      final items = <JobChecklistItemRead>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final parsed = JobChecklistItemRead.tryFromMap(
          Map<String, dynamic>.from(
            entry.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
        if (parsed != null) items.add(parsed);
      }
      items.sort((a, b) => a.sequence.compareTo(b.sequence));
      return items;
    }
    return const [];
  }

  static JobChecklistRead? tryFromMap(dynamic raw) {
    if (raw is List) {
      final items = parseItems(raw);
      if (items.isEmpty) return null;
      return JobChecklistRead(
        isMarked: items.every((item) => !item.isRequired || item.isChecked),
        items: items,
      );
    }
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    final items = parseItems(map['items']);
    if (items.isEmpty) return null;
    return JobChecklistRead(
      isMarked: JobRead._readBool(map['is_marked']) ?? false,
      items: items,
    );
  }
}

/// Paginated jobs list from `GET /api/v1/jobs/`.
class JobsPageResult {
  const JobsPageResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
  });

  final List<JobRead> items;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
}
