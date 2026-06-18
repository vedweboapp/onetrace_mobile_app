import 'package:flutter/foundation.dart';

@immutable
final class QrCodeNamedEntity {
  const QrCodeNamedEntity({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  static QrCodeNamedEntity? tryFromMap(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
    final id = _readInt(map['id']);
    final name = _readString(map, const ['name', 'title', 'label']);
    if (id == null || name == null) return null;
    return QrCodeNamedEntity(id: id, name: name);
  }
}

@immutable
final class QrCodeJobDetails {
  const QrCodeJobDetails({
    required this.jobId,
    required this.title,
    this.jobSerialNumber,
    this.project,
    this.site,
    this.workers = const [],
    this.forms = const [],
    this.qrCode,
  });

  final int jobId;
  final String title;
  final String? jobSerialNumber;
  final QrCodeNamedEntity? project;
  final QrCodeNamedEntity? site;
  final List<QrCodeNamedEntity> workers;
  final List<QrCodeNamedEntity> forms;
  final String? qrCode;

  static QrCodeJobDetails? tryFromMap(
    Map<String, dynamic> map, {
    String? qrCode,
  }) {
    final jobMap = _readMap(map['job']);
    final jobId = _readInt(map['job_id']) ??
        _readInt(map['jobId']) ??
        _readFkId(map['job']) ??
        (jobMap != null ? _readInt(jobMap['id']) : null);
    if (jobId == null) return null;

    final title = _readString(map, const ['title', 'job_title']) ??
        (jobMap != null
            ? _readString(jobMap, const ['title', 'name', 'job_title'])
            : null) ??
        'Job';
    final workers = _readEntityList(map['workers']);
    final forms = _readEntityList(map['forms']);

    return QrCodeJobDetails(
      jobId: jobId,
      title: title,
      jobSerialNumber: _readString(
            map,
            const ['job_serial_number', 'serial_number'],
          ) ??
          (jobMap != null
              ? _readString(jobMap, const ['serial_number', 'job_serial_number'])
              : null),
      project: QrCodeNamedEntity.tryFromMap(map['project']) ??
          (jobMap != null ? QrCodeNamedEntity.tryFromMap(jobMap['project']) : null),
      site: QrCodeNamedEntity.tryFromMap(map['site']) ??
          (jobMap != null ? QrCodeNamedEntity.tryFromMap(jobMap['site']) : null),
      workers: workers,
      forms: forms,
      qrCode: qrCode ??
          _readString(map, const ['qr_code', 'code']) ??
          _readString(jobMap ?? const {}, const ['qr_code', 'code']),
    );
  }
}

Map<String, dynamic>? _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return null;
}

int? _readFkId(dynamic value) {
  if (value is Map) {
    return _readInt(_readMap(value)?['id']);
  }
  return _readInt(value);
}

List<QrCodeNamedEntity> _readEntityList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map(QrCodeNamedEntity.tryFromMap)
      .whereType<QrCodeNamedEntity>()
      .toList(growable: false);
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().trim());
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
