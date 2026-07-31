import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';

enum EmployeeJobCategory {
  project,
  service,
  unknown;

  static EmployeeJobCategory fromApi(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    if (value.contains('service')) return EmployeeJobCategory.service;
    if (value.contains('project')) return EmployeeJobCategory.project;
    return EmployeeJobCategory.unknown;
  }

  bool get isProject => this == EmployeeJobCategory.project;
  bool get isService => this == EmployeeJobCategory.service;
}

final class EmployeeJobDetail {
  const EmployeeJobDetail({
    required this.id,
    required this.title,
    required this.currentStatus,
    required this.project,
    required this.client,
    required this.siteContact,
    required this.block,
    required this.plot,
    required this.description,
    required this.items,
    required this.safetyChecklist,
    this.formId,
    this.formIds = const [],
    this.formAssignments = const [],
    this.jobForms = const [],
    this.projectId,
    this.levels = const [],
    this.pinFormTasks = const [],
    this.siteDetail,
    this.jobSerialNumber,
    this.jobCategory = EmployeeJobCategory.unknown,
    this.hasJobQrField = false,
  });

  final int id;
  final String title;
  final String currentStatus;
  final String project;
  final String client;
  final String siteContact;
  final String block;
  final String plot;
  final String description;
  final List<EmployeeJobItem> items;
  final List<EmployeeSafetyChecklistItem> safetyChecklist;
  final int? formId;
  final List<int> formIds;
  final List<JobFormAssignment> formAssignments;
  final List<JobLinkedFormSummary> jobForms;
  final int? projectId;
  final List<EmployeeJobDrawingLevel> levels;
  final List<EmployeeJobPinFormTask> pinFormTasks;
  final EmployeeJobSiteDetail? siteDetail;
  final String? jobSerialNumber;
  final EmployeeJobCategory jobCategory;

  /// True when the job payload includes a top-level `qr_code` key.
  final bool hasJobQrField;

  bool get hasDrawingHierarchy =>
      levels.any(
        (level) =>
            level.pinCount > 0 ||
            (level.drawingFileUrl?.trim().isNotEmpty ?? false),
      );

  /// Project jobs use drawings/pins; service jobs use linked forms only.
  bool get usesDesignsWorkflow {
    if (jobCategory.isService) return false;
    if (jobCategory.isProject) return hasDrawingHierarchy;
    return collectJobPinEntries(levels).isNotEmpty;
  }

  String get siteLocationTitle =>
      siteDetail?.name.trim().isNotEmpty == true
          ? siteDetail!.name.trim()
          : block.trim().isNotEmpty
              ? block.trim()
              : title;

  String get siteLocationAddress {
    final siteAddress = siteDetail?.address.trim() ?? '';
    if (siteAddress.isNotEmpty) return siteAddress;
    final blockPlot = [
      if (block.trim().isNotEmpty) block.trim(),
      if (plot.trim().isNotEmpty) plot.trim(),
    ].join(', ');
    return blockPlot;
  }

  List<int> get linkedFormIds {
    if (pinFormTasks.isNotEmpty) {
      return pinFormTasks.map((task) => task.formId).toSet().toList(growable: false);
    }
    if (jobForms.isNotEmpty) {
      return jobForms.map((form) => form.formId).toList(growable: false);
    }
    if (formAssignments.isNotEmpty) {
      return formAssignments.map((a) => a.formId).toList(growable: false);
    }
    if (formIds.isNotEmpty) return formIds;
    if (formId != null) return [formId!];
    return const [];
  }

  int? jobFormIdFor(int formTemplateId) {
    for (final assignment in formAssignments) {
      if (assignment.formId == formTemplateId) return assignment.jobFormId;
    }
    return null;
  }

  int? jobPinIdForPin(int pinId, int formTemplateId) {
    for (final task in pinFormTasks) {
      if (task.pinId == pinId && task.formId == formTemplateId) {
        return task.jobPinId;
      }
    }
    return null;
  }

  EmployeeJobDetail copyWith({
    String? currentStatus,
    List<int>? formIds,
    List<JobFormAssignment>? formAssignments,
    List<JobLinkedFormSummary>? jobForms,
    List<EmployeeJobDrawingLevel>? levels,
    List<EmployeeJobPinFormTask>? pinFormTasks,
    List<EmployeeSafetyChecklistItem>? safetyChecklist,
    EmployeeJobCategory? jobCategory,
    bool? hasJobQrField,
  }) {
    return EmployeeJobDetail(
      id: id,
      title: title,
      currentStatus: currentStatus ?? this.currentStatus,
      project: project,
      client: client,
      siteContact: siteContact,
      block: block,
      plot: plot,
      description: description,
      items: items,
      safetyChecklist: safetyChecklist ?? this.safetyChecklist,
      formId: formId,
      formIds: formIds ?? this.formIds,
      formAssignments: formAssignments ?? this.formAssignments,
      jobForms: jobForms ?? this.jobForms,
      projectId: projectId,
      levels: levels ?? this.levels,
      pinFormTasks: pinFormTasks ?? this.pinFormTasks,
      siteDetail: siteDetail,
      jobSerialNumber: jobSerialNumber,
      jobCategory: jobCategory ?? this.jobCategory,
      hasJobQrField: hasJobQrField ?? this.hasJobQrField,
    );
  }
}

final class EmployeeJobSummary {
  const EmployeeJobSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.earning,
    required this.location,
    required this.schedule,
    required this.primaryActionLabel,
    this.startDate,
    this.siteName,
    this.projectName,
    this.projectId,
  });

  final int id;
  final String title;
  final EmployeeJobStatus status;
  final String earning;
  final String location;
  final String schedule;
  final String primaryActionLabel;
  final DateTime? startDate;
  final String? siteName;
  final String? projectName;
  final int? projectId;

  /// Primary site label for operative job cards.
  String get displaySiteName {
    final site = siteName?.trim();
    if (site != null && site.isNotEmpty) return site;
    return title;
  }

  /// Location line under the job title (site and project).
  String get displayLocationLine => displaySiteSubtitle;

  /// Secondary line under the job name (site + project when available).
  String get displaySiteSubtitle {
    final site = siteName?.trim();
    final project = projectName?.trim();
    if (site != null &&
        site.isNotEmpty &&
        project != null &&
        project.isNotEmpty) {
      return '$site - $project';
    }
    if (project != null && project.isNotEmpty) return project;
    return location;
  }
}

enum EmployeeJobStatus {
  inProgress('IN PROGRESS'),
  upcoming('UPCOMING'),
  pending('PENDING'),
  completed('COMPLETED');

  const EmployeeJobStatus(this.label);

  final String label;
}

final class EmployeeJobItem {
  const EmployeeJobItem({
    required this.name,
    required this.quantityLabel,
    required this.iconName,
  });

  final String name;
  final String quantityLabel;
  final String iconName;
}

final class EmployeeRequiredFormItem {
  const EmployeeRequiredFormItem({
    required this.id,
    required this.title,
    required this.isComplete,
    this.isOptional = false,
    this.isActionable = true,
  });

  final String id;
  final String title;
  final bool isComplete;
  final bool isOptional;
  final bool isActionable;
}

final class EmployeeSafetyChecklistItem {
  const EmployeeSafetyChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
    this.isRequired = true,
    this.sequence = 0,
    this.fileUrl,
    this.isMarked = false,
    this.requiresConcentricPoint = false,
    this.concentricPointConfirmed,
  });

  final String id;
  final String title;
  final bool isChecked;
  final bool isRequired;
  final int sequence;
  final String? fileUrl;
  final bool isMarked;

  /// Template flag from API — item needs operative concentric confirmation.
  final bool requiresConcentricPoint;

  /// Operative answer: `true` = verified, `false` = not verified, `null` = unanswered.
  final bool? concentricPointConfirmed;

  bool get hasPdf => fileUrl != null && fileUrl!.trim().isNotEmpty;

  bool get concentricPointAnswered =>
      !requiresConcentricPoint || concentricPointConfirmed != null;

  bool get concentricPointSatisfied =>
      !requiresConcentricPoint || concentricPointConfirmed == true;

  bool get submissionConcentricPoint =>
      requiresConcentricPoint && concentricPointConfirmed == true;

  EmployeeSafetyChecklistItem copyWith({
    bool? isChecked,
    bool? concentricPointConfirmed,
    bool resetConcentricPointConfirmed = false,
  }) {
    return EmployeeSafetyChecklistItem(
      id: id,
      title: title,
      isChecked: isChecked ?? this.isChecked,
      isRequired: isRequired,
      sequence: sequence,
      fileUrl: fileUrl,
      isMarked: isMarked,
      requiresConcentricPoint: requiresConcentricPoint,
      concentricPointConfirmed: resetConcentricPointConfirmed
          ? null
          : (concentricPointConfirmed ?? this.concentricPointConfirmed),
    );
  }
}
