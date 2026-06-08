import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

/// Completed job sheet with timesheet, compliance, and timeline.
final class EmployeeJobSheetDetail {
  const EmployeeJobSheetDetail({
    required this.id,
    required this.title,
    required this.statusLabel,
    required this.siteId,
    required this.startTime,
    required this.endTime,
    required this.totalWorked,
    required this.totalEarning,
    required this.complianceTitle,
    required this.complianceSubtitle,
    required this.complianceVerified,
    required this.timeline,
  });

  final int id;
  final String title;
  final String statusLabel;
  final String siteId;
  final String startTime;
  final String endTime;
  final String totalWorked;
  final String totalEarning;
  final String complianceTitle;
  final String complianceSubtitle;
  final bool complianceVerified;
  final List<EmployeeJobSheetTimelineStep> timeline;
}

final class EmployeeJobSheetTimelineStep {
  const EmployeeJobSheetTimelineStep({
    required this.label,
    this.timestamp,
    required this.state,
  });

  final String label;
  final String? timestamp;
  final EmployeeJobSheetTimelineState state;
}

enum EmployeeJobSheetTimelineState { muted, active, completed }

/// Mock job sheet list + detail (technician).
abstract final class EmployeeJobSheetData {
  EmployeeJobSheetData._();

  static const List<EmployeeJobSummary> jobs = [
    EmployeeJobSummary(
      id: 500,
      title: 'Install fire alarm units',
      status: EmployeeJobStatus.inProgress,
      earning: '\u00A364.00',
      location: 'Riverside Tower · Floor 7',
      schedule: 'Today · 10:00 AM – 4:30 PM',
      primaryActionLabel: 'View Details',
    ),
    EmployeeJobSummary(
      id: 501,
      title: 'Deliver copper pipes',
      status: EmployeeJobStatus.upcoming,
      earning: '\u00A342.50',
      location: 'Metro Mall · Loading Bay',
      schedule: 'Tomorrow · 8:30 AM',
      primaryActionLabel: 'View Details',
    ),
    EmployeeJobSummary(
      id: 502,
      title: 'Concrete quality check',
      status: EmployeeJobStatus.pending,
      earning: '\u00A355.00',
      location: 'Greenfield Site',
      schedule: 'Friday · 9:00 AM',
      primaryActionLabel: 'View Details',
    ),
  ];

  static EmployeeJobSheetDetail detailFor(int jobId) {
    return switch (jobId) {
      500 => _installFireAlarmDetail,
      501 => _deliverCopperDetail,
      _ => _defaultDetail,
    };
  }

  static const _installFireAlarmDetail = EmployeeJobSheetDetail(
    id: 500,
    title: 'Install fire alarm units',
    statusLabel: 'COMPLETED',
    siteId: '#CON-49210',
    startTime: '10:03 AM',
    endTime: '03:53 PM',
    totalWorked: '5h 20m',
    totalEarning: '\u00A3120.00',
    complianceTitle: 'Compliance Form',
    complianceSubtitle: 'Verified & Submitted',
    complianceVerified: true,
    timeline: [
      EmployeeJobSheetTimelineStep(
        label: 'Assigned',
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Accepted',
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Clocked In',
        timestamp: '10:03 AM',
        state: EmployeeJobSheetTimelineState.active,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Form Submitted',
        timestamp: '3:45 PM',
        state: EmployeeJobSheetTimelineState.active,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Completed',
        timestamp: '3:53 PM',
        state: EmployeeJobSheetTimelineState.completed,
      ),
    ],
  );

  static const _deliverCopperDetail = EmployeeJobSheetDetail(
    id: 501,
    title: 'Deliver copper pipes',
    statusLabel: 'UPCOMING',
    siteId: '#CON-50122',
    startTime: '—',
    endTime: '—',
    totalWorked: '—',
    totalEarning: '\u00A342.50',
    complianceTitle: 'Compliance Form',
    complianceSubtitle: 'Not started',
    complianceVerified: false,
    timeline: [
      EmployeeJobSheetTimelineStep(
        label: 'Assigned',
        state: EmployeeJobSheetTimelineState.completed,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Accepted',
        state: EmployeeJobSheetTimelineState.active,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Clocked In',
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Form Submitted',
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Completed',
        state: EmployeeJobSheetTimelineState.muted,
      ),
    ],
  );

  static const _defaultDetail = EmployeeJobSheetDetail(
    id: 502,
    title: 'Concrete quality check',
    statusLabel: 'PENDING',
    siteId: '#CON-50201',
    startTime: '—',
    endTime: '—',
    totalWorked: '—',
    totalEarning: '\u00A355.00',
    complianceTitle: 'Compliance Form',
    complianceSubtitle: 'Awaiting start',
    complianceVerified: false,
    timeline: [
      EmployeeJobSheetTimelineStep(
        label: 'Assigned',
        state: EmployeeJobSheetTimelineState.active,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Accepted',
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Clocked In',
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Form Submitted',
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Completed',
        state: EmployeeJobSheetTimelineState.muted,
      ),
    ],
  );
}
