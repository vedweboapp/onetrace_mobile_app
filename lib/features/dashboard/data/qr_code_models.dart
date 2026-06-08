import 'package:flutter/foundation.dart';

@immutable
final class QrCodeModel {
  const QrCodeModel({
    required this.id,
    required this.qrCodeId,
    required this.qrImageUrl,
    required this.status,
    required this.isAssigned,
    this.assignedToId,
    this.lastScannedAt,
    required this.scanCount,
    required this.createdAt,
    this.modifiedAt,
    this.createdByUsername,
    this.createdByEmail,
    this.modifiedByUsername,
    this.modifiedByEmail,
  });

  final int id;
  final String qrCodeId;
  final String? qrImageUrl;
  final String status;
  final bool isAssigned;
  final int? assignedToId;
  final DateTime? lastScannedAt;
  final int scanCount;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final String? createdByUsername;
  final String? createdByEmail;
  final String? modifiedByUsername;
  final String? modifiedByEmail;

  bool get isActiveStatus =>
      isAssigned ||
      status.trim().toLowerCase() == 'active' ||
      status.trim().toLowerCase() == 'assigned';

  String get statusLabel {
    if (isActiveStatus) return 'Active';
    if (status.trim().toLowerCase() == 'not_assigned') return 'Not assigned';
    final normalized = status.trim();
    if (normalized.isEmpty) return 'Not assigned';
    return normalized
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String get assignedJobLabel {
    if (assignedToId != null) return 'Job ID: $assignedToId';
    return 'Unassigned';
  }

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    final createdBy = _readUser(json['created_by']);
    final modifiedBy = _readUser(json['modified_by']);
    return QrCodeModel(
      id: _readInt(json['id']) ?? 0,
      qrCodeId: _readString(json['qr_code_id']) ?? 'QR-${json['id'] ?? ''}',
      qrImageUrl: _readString(json['qr_image']),
      status: _readString(json['status']) ?? 'not_assigned',
      isAssigned: json['is_assigned'] == true,
      assignedToId: _readInt(json['assigned_to_id']),
      lastScannedAt: _readDateTime(json['last_scanned_at']),
      scanCount: _readInt(json['scan_count']) ?? 0,
      createdAt: _readDateTime(json['created_at']),
      modifiedAt: _readDateTime(json['modified_at']),
      createdByUsername: createdBy.$1,
      createdByEmail: createdBy.$2,
      modifiedByUsername: modifiedBy.$1,
      modifiedByEmail: modifiedBy.$2,
    );
  }
}

(String? username, String? email) _readUser(dynamic value) {
  if (value is! Map) return (null, null);
  final map = Map<String, dynamic>.from(value);
  final username = _readString(map['username']);
  final email = _readString(map['email']);
  return (username, email);
}

String? _readString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? _readDateTime(dynamic value) {
  final text = _readString(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}
