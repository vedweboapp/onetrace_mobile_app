final class EmployeeProjectDetail {
  const EmployeeProjectDetail({
    required this.id,
    required this.title,
    required this.status,
    required this.projectName,
    required this.clientName,
    required this.siteName,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.jobs,
    this.formIds = const [],
    this.activeSites = 0,
    this.isCompleted = false,
  });

  final int id;
  final String title;
  final String status;
  final String projectName;
  final String clientName;
  final String siteName;
  final String description;
  final String startDate;
  final String endDate;
  final List<EmployeeProjectJobItem> jobs;
  final List<int> formIds;
  final int activeSites;
  final bool isCompleted;
}

final class EmployeeProjectJobItem {
  const EmployeeProjectJobItem({
    required this.id,
    required this.title,
    required this.status,
    required this.earning,
    required this.location,
    required this.schedule,
    required this.actionLabel,
  });

  final int id;
  final String title;
  final String status;
  final String earning;
  final String location;
  final String schedule;
  final String actionLabel;
}

enum EmployeeProjectCardStatus {
  inProgress('IN PROGRESS'),
  scheduled('SCHEDULED'),
  review('REVIEW');

  const EmployeeProjectCardStatus(this.label);

  final String label;
}

final class EmployeeProjectSummary {
  const EmployeeProjectSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.dueDate,
    required this.client,
    required this.site,
    required this.activeSites,
    required this.isCompleted,
    required this.jobCount,
    required this.address,
    required this.cardStatus,
  });

  final int id;
  final String title;
  final String status;
  final String dueDate;
  final String client;
  final String site;
  final int activeSites;
  final bool isCompleted;
  final int jobCount;
  final String address;
  final EmployeeProjectCardStatus cardStatus;
}
