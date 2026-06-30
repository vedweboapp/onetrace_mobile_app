import 'package:red5/employee_role/jobs/data/job_form_models.dart';

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

  List<int> get linkedFormIds {
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

  EmployeeJobDetail copyWith({
    String? currentStatus,
    List<int>? formIds,
    List<JobFormAssignment>? formAssignments,
    List<JobLinkedFormSummary>? jobForms,
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
      safetyChecklist: safetyChecklist,
      formId: formId,
      formIds: formIds ?? this.formIds,
      formAssignments: formAssignments ?? this.formAssignments,
      jobForms: jobForms ?? this.jobForms,
      projectId: projectId,
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
  });

  final String id;
  final String title;
  final bool isComplete;
  final bool isOptional;
}

final class EmployeeSafetyChecklistItem {
  const EmployeeSafetyChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
    this.isRequired = true,
    this.sequence = 0,
  });

  final String id;
  final String title;
  final bool isChecked;
  final bool isRequired;
  final int sequence;

  EmployeeSafetyChecklistItem copyWith({bool? isChecked}) {
    return EmployeeSafetyChecklistItem(
      id: id,
      title: title,
      isChecked: isChecked ?? this.isChecked,
      isRequired: isRequired,
      sequence: sequence,
    );
  }
}
