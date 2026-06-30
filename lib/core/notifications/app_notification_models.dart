import 'dart:convert';

import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

enum AppNotificationType { jobAssigned }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.jobId,
    this.jobTitle,
    this.isRead = false,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final int? jobId;
  final String? jobTitle;
  final bool isRead;

  factory AppNotification.jobAssigned(EmployeeJobSummary job) {
    final location = job.location.trim();
    final project = job.projectName?.trim();
    final details = <String>[
      if (project != null && project.isNotEmpty) project,
      if (location.isNotEmpty) location,
    ].join(' · ');

    return AppNotification(
      id: 'job-${job.id}-${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.jobAssigned,
      title: 'New task assigned',
      body: details.isEmpty
          ? 'You were assigned "${job.title}".'
          : '${job.title} — $details',
      createdAt: DateTime.now(),
      jobId: job.id,
      jobTitle: job.title,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      jobId: jobId,
      jobTitle: jobTitle,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
    if (jobId != null) 'job_id': jobId,
    if (jobTitle != null && jobTitle!.isNotEmpty) 'job_title': jobTitle,
    'is_read': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['type'] as String?)?.trim() ?? '';
    final type = AppNotificationType.values.firstWhere(
      (value) => value.name == typeRaw,
      orElse: () => AppNotificationType.jobAssigned,
    );
    final createdRaw = (json['created_at'] as String?)?.trim();
    return AppNotification(
      id: (json['id'] as String?)?.trim() ?? '',
      type: type,
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
          .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String listToJsonString(List<AppNotification> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList(growable: false));
  }
}

final class AppNotificationsState {
  const AppNotificationsState({
    this.items = const [],
    this.isInitialized = false,
  });

  final List<AppNotification> items;
  final bool isInitialized;

  int get unreadCount => items.where((item) => !item.isRead).length;

  AppNotificationsState copyWith({
    List<AppNotification>? items,
    bool? isInitialized,
  }) {
    return AppNotificationsState(
      items: items ?? this.items,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}
