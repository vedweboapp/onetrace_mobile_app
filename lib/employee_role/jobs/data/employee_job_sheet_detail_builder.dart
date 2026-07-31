import 'package:intl/intl.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/employee_job_sheet.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

/// Builds [EmployeeJobSheetDetail] for the operative job summary screen.
abstract final class EmployeeJobSheetDetailBuilder {
  EmployeeJobSheetDetailBuilder._();

  static final _timeFormat = DateFormat('h:mm a');
  static final _dateTimeFormat = DateFormat('MMM d, yyyy · h:mm a');

  static EmployeeJobSheetDetail build({
    required EmployeeJobSummary summary,
    EmployeeJobDetail? detail,
    JobRead? jobRead,
    required EmployeeJobSessionController session,
    Set<int> completedFormIds = const {},
    bool allFormsComplete = false,
  }) {
    final completed = _isJobCompleted(summary, jobRead, session);
    final started = _isJobStarted(summary, jobRead, session);
    final accepted = started || session.isJobStarted(summary.id);
    final formsDone = allFormsComplete ||
        (detail != null &&
            detail.pinFormTasks.isNotEmpty &&
            detail.pinFormTasks.every((task) {
              final pin = findEmployeeJobPinById(detail.levels, task.pinId);
              return pin?.isFormSubmitted == true || pin?.isStatusComplete == true;
            })) ||
        (detail != null &&
            detail.linkedFormIds.isNotEmpty &&
            detail.linkedFormIds.every(completedFormIds.contains));

    final startAt = _resolveStartAt(jobRead, summary);
    final endAt = _resolveEndAt(jobRead, completed);
    final worked = _formatWorkedDuration(startAt, endAt);

    final statusLabel = detail?.currentStatus.trim().isNotEmpty == true
        ? detail!.currentStatus.toUpperCase()
        : summary.status.label;

    return EmployeeJobSheetDetail(
      id: summary.id,
      title: detail?.title ?? summary.title,
      statusLabel: statusLabel,
      siteId: _formatSiteId(jobRead, detail, summary.id),
      startTime: _formatTime(startAt),
      endTime: _formatTime(endAt),
      totalWorked: worked,
      totalEarning: summary.earning,
      complianceTitle: 'Compliance Form',
      complianceSubtitle: _complianceSubtitle(
        hasForms: (detail?.linkedFormIds ?? const []).isNotEmpty ||
            (detail?.pinFormTasks ?? const []).isNotEmpty,
        formsDone: formsDone,
        started: started,
      ),
      complianceVerified: formsDone,
      timeline: _buildTimeline(
        completed: completed,
        accepted: accepted,
        started: started,
        formsDone: formsDone,
        startAt: startAt,
        endAt: endAt,
        createdAt: jobRead?.raw['created_at'],
        modifiedAt: jobRead?.raw['modified_at'],
      ),
    );
  }

  static bool _isJobCompleted(
    EmployeeJobSummary summary,
    JobRead? jobRead,
    EmployeeJobSessionController session,
  ) {
    return summary.status == EmployeeJobStatus.completed ||
        session.isJobCompleted(summary.id) ||
        jobRead?.completedAt != null;
  }

  static bool _isJobStarted(
    EmployeeJobSummary summary,
    JobRead? jobRead,
    EmployeeJobSessionController session,
  ) {
    if (session.isJobStarted(summary.id)) return true;
    if (summary.status == EmployeeJobStatus.inProgress) return true;
    final status = jobRead?.displayStatus.toUpperCase() ?? '';
    return status.contains('PROGRESS') || status.contains('ACTIVE');
  }

  static DateTime? _resolveStartAt(JobRead? jobRead, EmployeeJobSummary summary) {
    return jobRead?.startDate?.toLocal() ?? summary.startDate?.toLocal();
  }

  static DateTime? _resolveEndAt(JobRead? jobRead, bool completed) {
    if (!completed) return null;
    return jobRead?.completedAt?.toLocal() ??
        jobRead?.endDate?.toLocal();
  }

  static String _formatSiteId(
    JobRead? jobRead,
    EmployeeJobDetail? detail,
    int jobId,
  ) {
    final serial = jobRead?.raw['job_serial_number']?.toString().trim() ??
        detail?.jobSerialNumber?.trim();
    if (serial != null && serial.isNotEmpty) {
      return serial.startsWith('#') ? serial : '#$serial';
    }
    return '#JOB-$jobId';
  }

  static String _formatTime(DateTime? value) {
    if (value == null) return '—';
    return _timeFormat.format(value);
  }

  static String _formatWorkedDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    final diff = end.difference(start);
    if (diff.isNegative) return '—';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  static String _complianceSubtitle({
    required bool hasForms,
    required bool formsDone,
    required bool started,
  }) {
    if (!hasForms) return 'No form required';
    if (formsDone) return 'Verified & Submitted';
    if (started) return 'In progress';
    return 'Not started';
  }

  static List<EmployeeJobSheetTimelineStep> _buildTimeline({
    required bool completed,
    required bool accepted,
    required bool started,
    required bool formsDone,
    required DateTime? startAt,
    required DateTime? endAt,
    required dynamic createdAt,
    required dynamic modifiedAt,
  }) {
    final created = _parseDate(createdAt);
    final modified = _parseDate(modifiedAt);

    final clockedReached = started || completed;
    final formsReached = formsDone || completed;

    return [
      EmployeeJobSheetTimelineStep(
        label: 'Assigned',
        timestamp: created != null ? _dateTimeFormat.format(created) : null,
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Accepted',
        state: EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Clocked In',
        timestamp: startAt != null ? _formatTime(startAt) : null,
        state: completed
            ? EmployeeJobSheetTimelineState.active
            : clockedReached
                ? EmployeeJobSheetTimelineState.active
                : EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Form Submitted',
        timestamp: formsDone && modified != null
            ? _formatTime(modified)
            : null,
        state: completed
            ? EmployeeJobSheetTimelineState.active
            : formsReached
                ? EmployeeJobSheetTimelineState.active
                : EmployeeJobSheetTimelineState.muted,
      ),
      EmployeeJobSheetTimelineStep(
        label: 'Completed',
        timestamp: endAt != null ? _formatTime(endAt) : null,
        state: completed
            ? EmployeeJobSheetTimelineState.completed
            : EmployeeJobSheetTimelineState.muted,
      ),
    ];
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    return DateTime.tryParse(raw.toString())?.toLocal();
  }
}
