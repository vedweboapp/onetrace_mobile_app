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

/// Lightweight dispatch row from `GET /dispatch/?job=&worker=`.
@immutable
final class MaterialDispatchRead {
  const MaterialDispatchRead({
    required this.id,
    required this.code,
    this.jobId,
    this.workerId,
    this.statusName,
    this.dispatchTo,
    this.receivedBy,
    this.dispatchDate,
    this.materialRequestCode,
    this.items = const [],
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String code;
  final int? jobId;
  final int? workerId;
  final String? statusName;
  final String? dispatchTo;
  final String? receivedBy;
  final DateTime? dispatchDate;
  final String? materialRequestCode;
  final List<MaterialDispatchItemRead> items;
  final Map<String, dynamic> raw;

  static MaterialDispatchRead? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final code = map['dispatch_number']?.toString().trim() ??
        map['serial_number']?.toString().trim() ??
        map['code']?.toString().trim() ??
        'DISP$id';
    final statusMap = _asMap(map['status']);
    final items = <MaterialDispatchItemRead>[];
    final itemsRaw = map['items'] ??
        map['dispatch_line'] ??
        map['dispatch_lines'] ??
        map['lines'];
    if (itemsRaw is List) {
      for (final row in itemsRaw) {
        final parsed = MaterialDispatchItemRead.tryFrom(row);
        if (parsed != null) items.add(parsed);
      }
    }

    return MaterialDispatchRead(
      id: id,
      code: code.isEmpty ? 'DISP$id' : code,
      jobId: _readInt(map['job']) ?? _readInt(map['job_id']),
      // Dispatch model uses `worker` / `worker_id` (not job_worker).
      workerId: _readInt(_asMap(map['worker'])?['id']) ??
          _readInt(map['worker']) ??
          _readInt(map['worker_id']),
      statusName: statusMap?['name']?.toString() ??
          map['status_name']?.toString(),
      dispatchTo: map['dispatch_to']?.toString().trim() ??
          _personName(_asMap(map['dispatch_to'])) ??
          _personName(_asMap(map['worker'])),
      receivedBy: map['received_by']?.toString().trim() ??
          _personName(_asMap(map['received_by'])),
      dispatchDate: _readDate(map['dispatch_date'] ?? map['created_at']),
      materialRequestCode: map['material_request_number']?.toString().trim() ??
          map['material_request']?.toString().trim() ??
          _asMap(map['material_request'])?['request_number']?.toString().trim(),
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
  });

  final int id;
  final String itemName;
  final String quantityLabel;

  static MaterialDispatchItemRead? tryFrom(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    final id = _readInt(map['id']) ?? _readInt(map['item']) ?? 0;
    final name = map['item_name']?.toString().trim() ??
        map['name']?.toString().trim() ??
        'Item';
    final qty = _readInt(map['quantity']) ??
        _readInt(map['dispatched_quantity']) ??
        _readInt(map['qty']);
    final unit = map['unit']?.toString().trim();
    final quantityLabel = qty == null
        ? (map['quantity_label']?.toString().trim() ?? '—')
        : (unit == null || unit.isEmpty ? '$qty' : '$qty $unit');
    return MaterialDispatchItemRead(
      id: id,
      itemName: name.isEmpty ? 'Item' : name,
      quantityLabel: quantityLabel,
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
    this.statusName,
    this.requestedDate,
    this.itemCount = 0,
    this.totalQuantity = 0,
    this.items = const [],
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String code;
  final int? jobId;
  final int? workerId;
  final String? statusName;
  final DateTime? requestedDate;
  final int itemCount;
  final int totalQuantity;
  final List<MaterialReturnItemRead> items;
  final Map<String, dynamic> raw;

  static MaterialReturnRequestRead? tryFromMap(Map<String, dynamic> map) {
    final id = _readInt(map['id']);
    if (id == null) return null;
    final code = map['return_number']?.toString().trim() ??
        map['request_number']?.toString().trim() ??
        map['serial_number']?.toString().trim() ??
        'RS-${id.toString().padLeft(5, '0')}';
    final statusMap = _asMap(map['status']);
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
    final totalQty = items.fold<int>(0, (sum, item) => sum + item.quantity);
    return MaterialReturnRequestRead(
      id: id,
      code: code.isEmpty ? 'RS-${id.toString().padLeft(5, '0')}' : code,
      jobId: _readInt(map['job']) ?? _readInt(map['job_id']),
      // Return-request model uses `worker` / `worker_id` (not job_worker).
      workerId: _readInt(_asMap(map['worker'])?['id']) ??
          _readInt(map['worker']) ??
          _readInt(map['worker_id']),
      statusName: statusMap?['name']?.toString() ??
          map['status_name']?.toString() ??
          'Return request',
      requestedDate: _readDate(
        map['requested_date'] ?? map['return_date'] ?? map['created_at'],
      ),
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
  });

  final int id;
  final String itemName;
  final int quantity;
  final String? quantityLabel;

  String get displayQuantity =>
      quantityLabel?.trim().isNotEmpty == true
          ? quantityLabel!.trim()
          : 'Qty: $quantity units';

  static MaterialReturnItemRead? tryFrom(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    final id = _readInt(map['id']) ?? _readInt(map['item']) ?? 0;
    final name = map['item_name']?.toString().trim() ??
        map['name']?.toString().trim() ??
        'Item';
    final qty = _readInt(map['quantity']) ??
        _readInt(map['returned_quantity']) ??
        _readInt(map['qty']) ??
        0;
    return MaterialReturnItemRead(
      id: id,
      itemName: name.isEmpty ? 'Item' : name,
      quantity: qty,
      quantityLabel: map['quantity_label']?.toString().trim(),
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
