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
    required this.materials,
    required this.safetyChecklist,
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
  final List<EmployeeJobMaterial> materials;
  final List<EmployeeSafetyChecklistItem> safetyChecklist;
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
  });

  final int id;
  final String title;
  final EmployeeJobStatus status;
  final String earning;
  final String location;
  final String schedule;
  final String primaryActionLabel;
}

enum EmployeeJobStatus {
  inProgress('IN PROGRESS'),
  upcoming('UPCOMING'),
  pending('PENDING'),
  completed('COMPLETED');

  const EmployeeJobStatus(this.label);

  final String label;
}

final class EmployeeJobMaterial {
  const EmployeeJobMaterial({
    required this.name,
    required this.quantity,
    required this.iconName,
  });

  final String name;
  final String quantity;
  final String iconName;
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
