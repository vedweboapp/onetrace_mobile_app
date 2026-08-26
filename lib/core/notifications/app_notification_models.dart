/// Local helpers kept for assignment-toast tracking only.
/// Inbox list / unread badge come from `/api/v1/notifications/`.

import 'dart:convert';

import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

/// Legacy local notification row (assignment toast bootstrap only).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.jobId,
    this.jobTitle,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final int? jobId;
  final String? jobTitle;
  final bool isRead;

  factory AppNotification.jobAssigned(EmployeeJobSummary job) {
    return AppNotification(
      id: 'job-${job.id}-${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Job Assigned',
      body: 'You were assigned "${job.title}".',
      createdAt: DateTime.now(),
      jobId: job.id,
      jobTitle: job.title,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
    if (jobId != null) 'job_id': jobId,
    if (jobTitle != null && jobTitle!.isNotEmpty) 'job_title': jobTitle,
    'is_read': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final createdRaw = (json['created_at'] as String?)?.trim();
    return AppNotification(
      id: (json['id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? 'Notification',
      body: (json['body'] as String?)?.trim() ?? '',
      createdAt: createdRaw == null || createdRaw.isEmpty
          ? DateTime.now()
          : DateTime.tryParse(createdRaw) ?? DateTime.now(),
      jobId: json['job_id'] is int
          ? json['job_id'] as int
          : int.tryParse('${json['job_id']}'),
      jobTitle: (json['job_title'] as String?)?.trim(),
      isRead: json['is_read'] == true,
    );
  }

  static List<AppNotification> listFromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                AppNotification.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String listToJsonString(List<AppNotification> items) {
    return jsonEncode(
      items.map((item) => item.toJson()).toList(growable: false),
    );
  }
}
