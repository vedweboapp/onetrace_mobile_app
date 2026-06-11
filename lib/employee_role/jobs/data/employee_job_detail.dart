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
  final int? projectId;

  List<int> get linkedFormIds {
    if (formIds.isNotEmpty) return formIds;
    if (formId != null) return [formId!];
    return const [];
  }
}

/// Mandatory pre-start safety checks shown before the job timer begins.
abstract final class EmployeeJobPreStartSafetyChecklist {
  EmployeeJobPreStartSafetyChecklist._();

  static const items = [
    EmployeeSafetyChecklistItem(id: 'ppe', title: 'Wearing PPE'),
    EmployeeSafetyChecklistItem(id: 'equipment', title: 'Equipment Inspected'),
    EmployeeSafetyChecklistItem(id: 'work_area', title: 'Work Area Clear'),
    EmployeeSafetyChecklistItem(
      id: 'safety_guard',
      title: 'Safety Guard in Place',
    ),
  ];
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
  });

  final int id;
  final String title;
  final EmployeeJobStatus status;
  final String earning;
  final String location;
  final String schedule;
  final String primaryActionLabel;
  final DateTime? startDate;
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
  });

  final String id;
  final String title;
  final bool isComplete;
}

final class EmployeeSafetyChecklistItem {
  const EmployeeSafetyChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
  });

  final String id;
  final String title;
  final bool isChecked;

  EmployeeSafetyChecklistItem copyWith({bool? isChecked}) {
    return EmployeeSafetyChecklistItem(
      id: id,
      title: title,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}
