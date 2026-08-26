import 'package:flutter/foundation.dart';

/// Server `notification_type` values used for icons / labels.
enum NotificationType {
  jobAssigned,
  jobReassigned,
  jobRemoved,
  dueDateUpdated,
  jobStatusUpdated,
  newComment,
  newFormAssigned,
  submissionRejected,
  unknown;

  static NotificationType fromApi(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'JOB_ASSIGNED':
        return NotificationType.jobAssigned;
      case 'JOB_REASSIGNED':
        return NotificationType.jobReassigned;
      case 'JOB_REMOVED':
        return NotificationType.jobRemoved;
      case 'DUE_DATE_UPDATED':
        return NotificationType.dueDateUpdated;
      case 'JOB_STATUS_UPDATED':
        return NotificationType.jobStatusUpdated;
      case 'NEW_COMMENT':
        return NotificationType.newComment;
      case 'NEW_FORM_ASSIGNED':
      case 'FORM_ASSIGNED':
        return NotificationType.newFormAssigned;
      case 'SUBMISSION_REJECTED':
      case 'FORM_REJECTED':
        return NotificationType.submissionRejected;
      default:
        return NotificationType.unknown;
    }
  }

  String get displayLabel {
    switch (this) {
      case NotificationType.jobAssigned:
        return 'New Job Assigned';
      case NotificationType.jobReassigned:
        return 'Job Reassigned';
      case NotificationType.jobRemoved:
        return 'Job Removed';
      case NotificationType.dueDateUpdated:
        return 'Due Date Updated';
      case NotificationType.jobStatusUpdated:
        return 'Job Status Updated';
      case NotificationType.newComment:
        return 'New Comment';
      case NotificationType.newFormAssigned:
        return 'New Form Assigned';
      case NotificationType.submissionRejected:
        return 'Submission Rejected';
      case NotificationType.unknown:
        return 'Notification';
    }
  }
}

@immutable
class NotificationUserDetails {
  const NotificationUserDetails({
    required this.id,
    required this.fullName,
    required this.email,
    required this.userImage,
  });

  final String id;
  final String fullName;
  final String email;
  final String userImage;

  factory NotificationUserDetails.fromJson(Map<String, dynamic> json) {
    return NotificationUserDetails(
      id: _str(json['id']),
      fullName: _str(json['full_name'] ?? json['fullName']),
      email: _str(json['email']),
      userImage: _str(json['user_image'] ?? json['userImage']),
    );
  }
}

@immutable
class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
    this.sender,
    this.receiver,
  });

  final String id;
  final String title;
  final String message;
  final NotificationType notificationType;
  final String referenceId;
  final bool isRead;
  final DateTime createdAt;
  final NotificationUserDetails? sender;
  final NotificationUserDetails? receiver;

  /// Bold headline matching the design: `New Job Assigned - Fire Alarm`.
  String get headline {
    final context = title.trim();
    if (context.isEmpty) return notificationType.displayLabel;
    return '${notificationType.displayLabel} - $context';
  }

  int? get referenceIdAsInt => int.tryParse(referenceId.trim());

  AppNotificationItem copyWith({bool? isRead}) {
    return AppNotificationItem(
      id: id,
      title: title,
      message: message,
      notificationType: notificationType,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      sender: sender,
      receiver: receiver,
    );
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final typeRaw = _str(json['notification_type'] ?? json['notificationType']);
    final createdRaw = _str(json['created_at'] ?? json['createdAt']);
    return AppNotificationItem(
      id: _str(json['id']),
      title: _str(json['title']),
      message: _str(json['message'] ?? json['body']),
      notificationType: NotificationType.fromApi(typeRaw),
      referenceId: _str(json['reference_id'] ?? json['referenceId']),
      isRead: json['is_read'] == true || json['isRead'] == true,
      createdAt: createdRaw.isEmpty
          ? DateTime.now()
          : DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now(),
      sender: _user(json['sender_details'] ?? json['senderDetails']),
      receiver: _user(json['receiver_details'] ?? json['receiverDetails']),
    );
  }

  static NotificationUserDetails? _user(dynamic raw) {
    if (raw is! Map) return null;
    return NotificationUserDetails.fromJson(
      Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v))),
    );
  }
}

@immutable
class NotificationsPageResult {
  const NotificationsPageResult({
    required this.items,
    this.nextCursor,
  });

  final List<AppNotificationItem> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.trim().isNotEmpty;
}

String _str(dynamic raw) {
  if (raw == null) return '';
  final t = raw.toString().trim();
  return t == 'null' ? '' : t;
}
