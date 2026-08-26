import 'package:flutter/material.dart';

enum MaterialRequestStatus {
  pending,
  partiallyDispatched,
  dispatched,
}

extension MaterialRequestStatusX on MaterialRequestStatus {
  String get label => switch (this) {
        MaterialRequestStatus.pending => 'PENDING',
        MaterialRequestStatus.partiallyDispatched => 'PARTIALLY DISPATCHED',
        MaterialRequestStatus.dispatched => 'DISPATCHED',
      };

  static MaterialRequestStatus fromApiName(String? raw) {
    final name = raw?.trim().toUpperCase() ?? '';
    if (name.contains('PARTIAL')) {
      return MaterialRequestStatus.partiallyDispatched;
    }
    if (name.contains('DISPATCH')) {
      return MaterialRequestStatus.dispatched;
    }
    return MaterialRequestStatus.pending;
  }
}

final class MaterialRequestListItem {
  const MaterialRequestListItem({
    required this.id,
    required this.requestCode,
    required this.jobCode,
    required this.requesterName,
    required this.itemCount,
    required this.status,
    this.statusLabel,
    this.statusBg,
    this.statusFg,
  });

  final String id;
  final String requestCode;
  final String jobCode;
  final String requesterName;
  final int itemCount;
  final MaterialRequestStatus status;

  /// Prefer API status name/colours when present.
  final String? statusLabel;
  final Color? statusBg;
  final Color? statusFg;

  String get displayStatusLabel =>
      (statusLabel != null && statusLabel!.trim().isNotEmpty)
          ? statusLabel!.trim().toUpperCase()
          : status.label;

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return requestCode.toLowerCase().contains(q) ||
        jobCode.toLowerCase().contains(q) ||
        requesterName.toLowerCase().contains(q) ||
        displayStatusLabel.toLowerCase().contains(q);
  }
}

final class MaterialRequestJobLine {
  const MaterialRequestJobLine({
    required this.id,
    required this.jobCode,
    required this.projectName,
  });

  final String id;
  final String jobCode;
  final String projectName;
}

final class MaterialRequestItemLine {
  const MaterialRequestItemLine({
    required this.id,
    required this.itemName,
    required this.requestedLabel,
    required this.dispatchedLabel,
    required this.pendingLabel,
    this.jobName,
    this.quantity,
    this.highlightPending = false,
  });

  final String id;
  final String itemName;
  final String requestedLabel;
  final String dispatchedLabel;
  final String pendingLabel;
  final String? jobName;
  final String? quantity;
  final bool highlightPending;
}

final class MaterialRequestTimelineEvent {
  const MaterialRequestTimelineEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.trackingNumber,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? trackingNumber;
}

final class MaterialRequestDetail {
  const MaterialRequestDetail({
    required this.id,
    required this.requestCode,
    required this.workerName,
    required this.status,
    required this.jobs,
    required this.items,
    required this.dispatchItems,
    required this.timeline,
    this.statusLabel,
    this.statusBg,
    this.statusFg,
  });

  final String id;
  final String requestCode;
  final String workerName;
  final MaterialRequestStatus status;
  final List<MaterialRequestJobLine> jobs;
  final List<MaterialRequestItemLine> items;
  final List<MaterialRequestItemLine> dispatchItems;
  final List<MaterialRequestTimelineEvent> timeline;
  final String? statusLabel;
  final Color? statusBg;
  final Color? statusFg;

  String get displayStatusLabel =>
      (statusLabel != null && statusLabel!.trim().isNotEmpty)
          ? statusLabel!.trim().toUpperCase()
          : status.label;
}

/// Full material-request row from `GET /material-requests/`.
@immutable
final class MaterialRequestRead {
  const MaterialRequestRead({
    required this.id,
    required this.requestNumber,
    required this.status,
    required this.statusId,
    required this.statusName,
    required this.jobs,
    required this.lines,
    this.workerId,
    this.workerName,
    this.requestedDate,
    this.notes,
    this.statusBg,
    this.statusFg,
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String requestNumber;
  final MaterialRequestStatus status;
  final int? statusId;
  final String statusName;
  final Color? statusBg;
  final Color? statusFg;
  final int? workerId;
  final String? workerName;
  final DateTime? requestedDate;
  final String? notes;
  final List<MaterialRequestJobSummary> jobs;
  final List<MaterialRequestLineRead> lines;
  final Map<String, dynamic> raw;

  MaterialRequestListItem toListItem() {
    final jobCode = jobs.isEmpty
        ? '—'
        : jobs.map((j) => j.serialNumber).where((s) => s.isNotEmpty).join(', ');
    return MaterialRequestListItem(
      id: id.toString(),
      requestCode: requestNumber,
      jobCode: jobCode.isEmpty ? '—' : jobCode,
      requesterName: (workerName ?? '').trim().isEmpty
          ? 'Worker'
          : workerName!.trim(),
      itemCount: lines.length,
      status: status,
      statusLabel: statusName,
      statusBg: statusBg,
      statusFg: statusFg,
    );
  }

  MaterialRequestDetail toDetail() {
    final jobLines = [
      for (final job in jobs)
        MaterialRequestJobLine(
          id: job.id.toString(),
          jobCode: job.serialNumber,
          projectName: job.projectName?.trim().isNotEmpty == true
              ? job.projectName!
              : (job.clientName ?? '—'),
        ),
    ];
    final items = [
      for (final line in lines)
        MaterialRequestItemLine(
          id: line.id.toString(),
          itemName: line.itemName,
          requestedLabel: '${line.requestedQuantity}',
          dispatchedLabel: '${line.dispatchedQuantity}',
          pendingLabel: '${line.pendingQuantity}',
          highlightPending: line.pendingQuantity > 0,
          jobName: jobNameFor(line.jobId),
        ),
    ];
    final dispatchItems = [
      for (final line in lines.where((l) => l.dispatchedQuantity > 0))
        MaterialRequestItemLine(
          id: 'disp-${line.id}',
          itemName: line.itemName,
          requestedLabel: '${line.dispatchedQuantity}',
          dispatchedLabel: '',
          pendingLabel: '',
          quantity: '${line.dispatchedQuantity}',
          jobName: jobNameFor(line.jobId),
        ),
    ];

    return MaterialRequestDetail(
      id: id.toString(),
      requestCode: requestNumber,
      workerName: (workerName ?? '').trim().isEmpty
          ? 'Worker'
          : workerName!.trim(),
      status: status,
      statusLabel: statusName,
      statusBg: statusBg,
      statusFg: statusFg,
      jobs: jobLines,
      items: items,
      dispatchItems: dispatchItems,
      timeline: const [],
    );
  }

  String? jobNameFor(int? jobId) {
    if (jobId == null) return null;
    for (final job in jobs) {
      if (job.id == jobId) {
        if (job.projectName?.trim().isNotEmpty == true) return job.projectName;
        return job.serialNumber;
      }
    }
    return null;
  }

  static MaterialRequestRead? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null || id <= 0) return null;

    final statusMap = _asMap(map['status']);
    final statusName = statusMap?['name']?.toString().trim() ??
        map['status_name']?.toString().trim() ??
        'PENDING';
    final status = MaterialRequestStatusX.fromApiName(statusName);

    final workerMap = _asMap(map['job_worker']) ?? _asMap(map['worker']);
    final workerName = _personName(workerMap);

    final jobs = <MaterialRequestJobSummary>[];
    final jobsRaw = map['jobs'];
    if (jobsRaw is List) {
      for (final row in jobsRaw) {
        final parsed = MaterialRequestJobSummary.tryFrom(row);
        if (parsed != null) jobs.add(parsed);
      }
    }

    final lines = <MaterialRequestLineRead>[];
    final linesRaw =
        map['material_request_line'] ?? map['lines'] ?? map['items'];
    if (linesRaw is List) {
      for (final row in linesRaw) {
        final parsed = MaterialRequestLineRead.tryFrom(row);
        if (parsed != null) lines.add(parsed);
      }
    }

    return MaterialRequestRead(
      id: id,
      requestNumber: map['request_number']?.toString().trim().isNotEmpty == true
          ? map['request_number'].toString().trim()
          : 'MR$id',
      status: status,
      statusId: _readInt(statusMap?['id']),
      statusName: statusName,
      statusBg: _parseHexColor(statusMap?['bg_colour']),
      statusFg: _parseHexColor(statusMap?['text_colour']),
      workerId: _readInt(workerMap?['id']),
      workerName: workerName,
      requestedDate: _readDate(map['requested_date']),
      notes: map['notes']?.toString(),
      jobs: jobs,
      lines: lines,
      raw: map,
    );
  }
}

@immutable
final class MaterialRequestJobSummary {
  const MaterialRequestJobSummary({
    required this.id,
    required this.serialNumber,
    this.projectName,
    this.clientName,
  });

  final int id;
  final String serialNumber;
  final String? projectName;
  final String? clientName;

  static MaterialRequestJobSummary? tryFrom(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    final id = _readInt(map['id']);
    if (id == null) return null;
    final serial = map['serial_number']?.toString().trim() ??
        map['job_code']?.toString().trim() ??
        'JB-$id';
    return MaterialRequestJobSummary(
      id: id,
      serialNumber: serial.isEmpty ? 'JB-$id' : serial,
      projectName: map['project_name']?.toString().trim(),
      clientName: map['client_name']?.toString().trim(),
    );
  }
}

@immutable
final class MaterialRequestLineRead {
  const MaterialRequestLineRead({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.requestedQuantity,
    required this.dispatchedQuantity,
    required this.returnedQuantity,
    this.itemSku,
    this.jobId,
  });

  final int id;
  final int itemId;
  final String itemName;
  final String? itemSku;
  final int requestedQuantity;
  final int dispatchedQuantity;
  final int returnedQuantity;
  final int? jobId;

  int get pendingQuantity {
    final pending = requestedQuantity - dispatchedQuantity;
    return pending < 0 ? 0 : pending;
  }

  static MaterialRequestLineRead? tryFrom(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    final id = _readInt(map['id']);
    final itemId = _readInt(map['item']) ?? _readInt(map['item_id']);
    if (id == null || itemId == null) return null;
    final name = map['item_name']?.toString().trim() ??
        map['name']?.toString().trim() ??
        'Item $itemId';
    return MaterialRequestLineRead(
      id: id,
      itemId: itemId,
      itemName: name.isEmpty ? 'Item $itemId' : name,
      itemSku: map['item_sku']?.toString().trim(),
      requestedQuantity: _readInt(map['requested_quantity']) ?? 0,
      dispatchedQuantity: _readInt(map['dispatched_quantity']) ?? 0,
      returnedQuantity: _readInt(map['returned_quantity']) ?? 0,
      jobId: _readInt(map['job']) ?? _readInt(map['job_id']),
    );
  }
}

/// Lightweight dispatch row from `GET /dispatch/?worker=&material_request=`.
@immutable
final class MaterialDispatchRead {
  const MaterialDispatchRead({
    required this.id,
    required this.code,
    this.jobId,
    this.workerId,
    this.userOrgMapId,
    this.jobWorkerId,
    this.statusName,
    this.dispatchTo,
    this.receivedBy,
    this.dispatchDate,
    this.notes,
    this.materialRequestId,
    this.materialRequestCode,
    this.items = const [],
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String code;
  final int? jobId;
  final int? workerId;
  final int? userOrgMapId;
  final int? jobWorkerId;
  final String? statusName;
  final String? dispatchTo;
  final String? receivedBy;
  final DateTime? dispatchDate;
  final String? notes;
  final int? materialRequestId;
  final String? materialRequestCode;
  final List<MaterialDispatchItemRead> items;
  final Map<String, dynamic> raw;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));

  static MaterialDispatchRead? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final code = map['dispatch_order_number']?.toString().trim() ??
        map['dispatch_number']?.toString().trim() ??
        map['serial_number']?.toString().trim() ??
        map['code']?.toString().trim() ??
        'DISP$id';
    final statusRaw = map['status'];
    final statusMap = _asMap(statusRaw);
    final statusName = () {
      if (statusRaw is String && statusRaw.trim().isNotEmpty) {
        return statusRaw.trim();
      }
      return statusMap?['name']?.toString().trim() ??
          map['status_name']?.toString().trim();
    }();
    final items = <MaterialDispatchItemRead>[];
    final itemsRaw = map['lines'] ??
        map['items'] ??
        map['dispatch_line'] ??
        map['dispatch_lines'];
    if (itemsRaw is List) {
      for (final row in itemsRaw) {
        final parsed = MaterialDispatchItemRead.tryFrom(row);
        if (parsed != null) items.add(parsed);
      }
    }

    final workerMap = _asMap(map['worker']) ?? _asMap(map['job_worker']);
    final materialRequestMap = _asMap(map['material_request']);
    final materialRequestId = _readInt(map['material_request']) ??
        _readInt(map['material_request_id']) ??
        _readInt(materialRequestMap?['id']);
    final materialRequestCode =
        map['material_request_number']?.toString().trim() ??
            materialRequestMap?['request_number']?.toString().trim();
    final notes = map['notes']?.toString().trim();

    return MaterialDispatchRead(
      id: id,
      code: code.isEmpty ? 'DISP$id' : code,
      jobId: _readInt(map['job']) ??
          _readInt(map['job_id']) ??
          _readInt(_asMap(map['job'])?['id']),
      // API worker object uses user_org_map_id / job_worker_id (no bare id).
      workerId: _readInt(workerMap?['id']) ??
          _readInt(workerMap?['user_org_map_id']) ??
          _readInt(map['worker']) ??
          _readInt(map['worker_id']),
      userOrgMapId: _readInt(workerMap?['user_org_map_id']),
      jobWorkerId: _readInt(workerMap?['job_worker_id']) ??
          _readInt(workerMap?['id']),
      statusName: statusName,
      dispatchTo: map['dispatch_to']?.toString().trim() ??
          _personName(_asMap(map['dispatch_to'])) ??
          _personName(workerMap),
      receivedBy: map['received_by']?.toString().trim() ??
          _personName(_asMap(map['received_by'])),
      dispatchDate: _readDate(map['dispatch_date'] ?? map['created_at']),
      notes: notes == null || notes.isEmpty ? null : notes,
      materialRequestId: materialRequestId,
      materialRequestCode: materialRequestCode?.isNotEmpty == true
          ? materialRequestCode
          : (materialRequestId != null ? '$materialRequestId' : null),
      items: items,
      raw: map,
    );
  }
}

@immutable
final class MaterialDispatchItemRead {
  const MaterialDispatchItemRead({
    required this.id,
    required this.itemName,
    required this.quantityLabel,
    this.itemId,
    this.sku,
    this.quantity,
    this.pendingQuantity,
    this.returnedQuantity,
    this.materialRequestLineId,
    this.isExtra = false,
    this.remarks,
  });

  final int id;
  final String itemName;
  final String quantityLabel;
  final int? itemId;
  final String? sku;
  final int? quantity;
  final int? pendingQuantity;
  final int? returnedQuantity;
  final int? materialRequestLineId;
  final bool isExtra;
  final String? remarks;

  static MaterialDispatchItemRead? tryFrom(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    final itemMap = _asMap(map['item']);
    final id = _readInt(map['id']) ??
        _readInt(itemMap?['id']) ??
        _readInt(map['item']) ??
        0;
    final name = map['item_name']?.toString().trim() ??
        itemMap?['name']?.toString().trim() ??
        map['name']?.toString().trim() ??
        'Item';
    final qty = _readInt(map['quantity']) ??
        _readInt(map['dispatched_quantity']) ??
        _readInt(map['qty']);
    final unit = map['unit']?.toString().trim();
    final quantityLabel = qty == null
        ? (map['quantity_label']?.toString().trim() ?? '—')
        : (unit == null || unit.isEmpty ? '$qty' : '$qty $unit');
    final sku = map['item_sku']?.toString().trim() ??
        itemMap?['sku']?.toString().trim() ??
        map['sku']?.toString().trim();
    final remarks = map['remarks']?.toString().trim();
    final isExtraRaw = map['is_extra'];
    final isExtra = isExtraRaw == true ||
        isExtraRaw?.toString().trim().toLowerCase() == 'true';
    return MaterialDispatchItemRead(
      id: id,
      itemName: name.isEmpty ? 'Item' : name,
      quantityLabel: quantityLabel,
      itemId: _readInt(map['item']) ?? _readInt(itemMap?['id']),
      sku: sku == null || sku.isEmpty ? null : sku,
      quantity: qty,
      pendingQuantity: _readInt(map['pending_quantity']),
      returnedQuantity: _readInt(map['returned_quantity']),
      materialRequestLineId: _readInt(map['material_request_line']) ??
          _readInt(map['material_request_line_id']),
      isExtra: isExtra,
      remarks: remarks == null || remarks.isEmpty ? null : remarks,
    );
  }
}

/// Lightweight return-request row from `GET /return-request/?job=&worker=`.
@immutable
final class MaterialReturnRequestRead {
  const MaterialReturnRequestRead({
    required this.id,
    required this.code,
    this.jobId,
    this.workerId,
    this.userOrgMapId,
    this.jobWorkerId,
    this.workerName,
    this.materialRequestId,
    this.statusName,
    this.requestedDate,
    this.completedAt,
    this.itemCount = 0,
    this.totalQuantity = 0,
    this.items = const [],
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String code;
  final int? jobId;
  final int? workerId;
  final int? userOrgMapId;
  final int? jobWorkerId;
  final String? workerName;
  final int? materialRequestId;
  final String? statusName;
  final DateTime? requestedDate;
  final DateTime? completedAt;
  final int itemCount;
  final int totalQuantity;
  final List<MaterialReturnItemRead> items;
  final Map<String, dynamic> raw;

  String get displayStatusLabel {
    final rawStatus = statusName?.trim() ?? '';
    if (rawStatus.isEmpty) return 'Return request';
    if (rawStatus == rawStatus.toUpperCase() ||
        rawStatus == rawStatus.toLowerCase()) {
      return rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase();
    }
    return rawStatus;
  }

  Set<int> get dispatchLineIds => {
        for (final item in items)
          if (item.dispatchLineId != null && item.dispatchLineId! > 0)
            item.dispatchLineId!,
      };

  static MaterialReturnRequestRead? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final code = map['return_number']?.toString().trim() ??
        map['request_number']?.toString().trim() ??
        map['serial_number']?.toString().trim() ??
        'RS-${id.toString().padLeft(5, '0')}';
    final statusRaw = map['status'];
    final statusMap = _asMap(statusRaw);
    final statusName = () {
      if (statusRaw is String && statusRaw.trim().isNotEmpty) {
        return statusRaw.trim();
      }
      return statusMap?['name']?.toString().trim() ??
          map['status_name']?.toString().trim();
    }();
    final items = <MaterialReturnItemRead>[];
    final itemsRaw = map['items'] ??
        map['return_request_line'] ??
        map['return_lines'] ??
        map['lines'];
    if (itemsRaw is List) {
      for (final row in itemsRaw) {
        final parsed = MaterialReturnItemRead.tryFrom(row);
        if (parsed != null) items.add(parsed);
      }
    }
    final workerMap = _asMap(map['worker']) ?? _asMap(map['job_worker']);
    final materialRequestMap = _asMap(map['material_request']);
    final totalQty = items.fold<int>(0, (sum, item) => sum + item.quantity);
    return MaterialReturnRequestRead(
      id: id,
      code: code.isEmpty ? 'RS-${id.toString().padLeft(5, '0')}' : code,
      jobId: _readInt(map['job']) ??
          _readInt(map['job_id']) ??
          _readInt(_asMap(map['job'])?['id']),
      // API worker object uses user_org_map_id / job_worker_id (no bare id).
      workerId: _readInt(workerMap?['id']) ??
          _readInt(workerMap?['user_org_map_id']) ??
          _readInt(map['worker']) ??
          _readInt(map['worker_id']),
      userOrgMapId: _readInt(workerMap?['user_org_map_id']),
      jobWorkerId: _readInt(workerMap?['job_worker_id']) ??
          _readInt(workerMap?['id']),
      workerName: _personName(workerMap),
      materialRequestId: _readInt(map['material_request']) ??
          _readInt(map['material_request_id']) ??
          _readInt(materialRequestMap?['id']),
      statusName: statusName?.isNotEmpty == true ? statusName : 'Return request',
      requestedDate: _readDate(
        map['requested_at'] ??
            map['requested_date'] ??
            map['return_date'] ??
            map['created_at'],
      ),
      completedAt: _readDate(map['completed_at']),
      itemCount: items.isNotEmpty
          ? items.length
          : (_readInt(map['item_count']) ?? 0),
      totalQuantity: totalQty > 0
          ? totalQty
          : (_readInt(map['total_quantity']) ?? _readInt(map['quantity']) ?? 0),
      items: items,
      raw: map,
    );
  }
}

@immutable
final class MaterialReturnItemRead {
  const MaterialReturnItemRead({
    required this.id,
    required this.itemName,
    required this.quantity,
    this.quantityLabel,
    this.dispatchLineId,
    this.returnType,
    this.reason,
    this.sku,
    this.dispatchQuantity,
  });

  final int id;
  final String itemName;
  final int quantity;
  final String? quantityLabel;
  final int? dispatchLineId;
  final String? returnType;
  final String? reason;
  final String? sku;
  final int? dispatchQuantity;

  String get displayQuantity =>
      quantityLabel?.trim().isNotEmpty == true
          ? quantityLabel!.trim()
          : 'Qty: $quantity units';

  String? get displayReturnType {
    final raw = returnType?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw == raw.toUpperCase() || raw == raw.toLowerCase()) {
      return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
    }
    return raw;
  }

  static MaterialReturnItemRead? tryFrom(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    final itemMap = _asMap(map['item']);
    final id = _readInt(map['id']) ??
        _readInt(itemMap?['id']) ??
        _readInt(map['item']) ??
        0;
    final name = map['item_name']?.toString().trim() ??
        itemMap?['name']?.toString().trim() ??
        map['name']?.toString().trim() ??
        'Item';
    final qty = _readInt(map['quantity']) ??
        _readInt(map['returned_quantity']) ??
        _readInt(map['qty']) ??
        0;
    final sku = itemMap?['sku']?.toString().trim() ??
        map['item_sku']?.toString().trim() ??
        map['sku']?.toString().trim();
    return MaterialReturnItemRead(
      id: id,
      itemName: name.isEmpty ? 'Item' : name,
      quantity: qty,
      quantityLabel: map['quantity_label']?.toString().trim(),
      dispatchLineId: _readInt(map['dispatch_line']) ??
          _readInt(map['dispatch_line_id']) ??
          _readInt(_asMap(map['dispatch_line'])?['id']),
      returnType: map['return_type']?.toString().trim(),
      reason: map['reason']?.toString().trim(),
      sku: sku == null || sku.isEmpty ? null : sku,
      dispatchQuantity: _readInt(map['dispatch_quantity']),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return null;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String? _personName(Map<String, dynamic>? map) {
  if (map == null) return null;
  final first = map['first_name']?.toString().trim() ?? '';
  final last = map['last_name']?.toString().trim() ?? '';
  final combined = '$first $last'.trim();
  if (combined.isNotEmpty) return combined;
  final username = map['username']?.toString().trim();
  if (username != null && username.isNotEmpty) return username;
  final email = map['email']?.toString().trim();
  if (email != null && email.isNotEmpty) return email;
  return null;
}

Color? _parseHexColor(dynamic raw) {
  if (raw == null) return null;
  var hex = raw.toString().trim();
  if (hex.isEmpty) return null;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value);
}

abstract final class MaterialRequestMockData {
  MaterialRequestMockData._();

  static const jobOptions = [
    'Skyline Apartments Phase II',
    'Harbor Logistics Hub',
    'Downtown Office Fit-Out',
    'Riverside Retail Park',
  ];

  static const workerOptions = [
    'Johnathan Miller',
    'Rajesh Kumar',
    'Sarah Jenkins',
    'Chris Hall',
    'Jamie Fox',
  ];

  static const itemCatalog = [
    'Structural Steel Beams (HEB 200)',
    'Copper Wiring 2.5mm',
    'Fire-Rated Drywall Sheets',
    'HVAC Ducting Kit',
    'Concrete Mix — Grade M30',
  ];

  static final listItems = [
    const MaterialRequestListItem(
      id: 'req-8829',
      requestCode: 'REQ-8829',
      jobCode: 'JOB-1024',
      requesterName: 'Johnathan Miller',
      itemCount: 5,
      status: MaterialRequestStatus.pending,
    ),
    const MaterialRequestListItem(
      id: 'req-8830',
      requestCode: 'REQ-8830',
      jobCode: 'JOB-1041',
      requesterName: 'Rajesh Kumar',
      itemCount: 3,
      status: MaterialRequestStatus.partiallyDispatched,
    ),
    const MaterialRequestListItem(
      id: 'req-8831',
      requestCode: 'REQ-8831',
      jobCode: 'JOB-0998',
      requesterName: 'Sarah Jenkins',
      itemCount: 8,
      status: MaterialRequestStatus.dispatched,
    ),
    const MaterialRequestListItem(
      id: 'req-8832',
      requestCode: 'REQ-8832',
      jobCode: 'JOB-1102',
      requesterName: 'Chris Hall',
      itemCount: 2,
      status: MaterialRequestStatus.pending,
    ),
    const MaterialRequestListItem(
      id: 'req-8833',
      requestCode: 'REQ-8833',
      jobCode: 'JOB-1088',
      requesterName: 'Jamie Fox',
      itemCount: 6,
      status: MaterialRequestStatus.partiallyDispatched,
    ),
  ];

  static MaterialRequestListItem? listItemById(String id) {
    for (final item in listItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  static MaterialRequestDetail detailForId(String id) {
    final listItem = listItemById(id);
    final code = listItem?.requestCode ?? '#MR-2023-0842';
    final worker = listItem?.requesterName ?? 'Rajesh Kumar';
    final status = listItem?.status ?? MaterialRequestStatus.dispatched;

    return MaterialRequestDetail(
      id: id,
      requestCode: code,
      workerName: worker,
      status: status,
      jobs: const [
        MaterialRequestJobLine(
          id: 'job-1',
          jobCode: 'JOB-1024',
          projectName: 'Skyline Apartments Phase II',
        ),
        MaterialRequestJobLine(
          id: 'job-2',
          jobCode: 'JOB-1041',
          projectName: 'Harbor Logistics Hub',
        ),
      ],
      items: const [
        MaterialRequestItemLine(
          id: 'item-1',
          itemName: 'Structural Steel Beams (HEB 200)',
          requestedLabel: '12 Units',
          dispatchedLabel: '12 Units',
          pendingLabel: '—',
        ),
        MaterialRequestItemLine(
          id: 'item-2',
          itemName: 'Copper Wiring 2.5mm',
          requestedLabel: '8 Rolls',
          dispatchedLabel: '8 Rolls',
          pendingLabel: '—',
        ),
        MaterialRequestItemLine(
          id: 'item-3',
          itemName: 'Fire-Rated Drywall Sheets',
          requestedLabel: '24 Sheets',
          dispatchedLabel: '9 Sheets',
          pendingLabel: '15 Rolls',
          highlightPending: true,
        ),
      ],
      dispatchItems: const [
        MaterialRequestItemLine(
          id: 'disp-1',
          itemName: 'Structural Steel Beams (HEB 200)',
          requestedLabel: '15 Rolls',
          dispatchedLabel: '',
          pendingLabel: '',
          quantity: '15 Rolls',
        ),
        MaterialRequestItemLine(
          id: 'disp-2',
          itemName: 'Fire-Rated Drywall Sheets',
          requestedLabel: '15 Rolls',
          dispatchedLabel: '',
          pendingLabel: '',
          quantity: '15 Rolls',
        ),
      ],
      timeline: [
        MaterialRequestTimelineEvent(
          id: 'tl-1',
          title: '#DISP-098 Dispatch Created',
          subtitle:
              'Structural steel beams and drywall sheets dispatched to site.',
          timestamp: DateTime(2023, 10, 15, 9, 30),
          trackingNumber: 'LOG-4491-X',
        ),
        MaterialRequestTimelineEvent(
          id: 'tl-2',
          title: 'Initial Request Fulfilment',
          subtitle: 'First batch of copper wiring marked as fulfilled.',
          timestamp: DateTime(2023, 10, 14, 16, 15),
        ),
      ],
    );
  }
}
