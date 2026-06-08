final class EmployeeProjectDetail {
  const EmployeeProjectDetail({
    required this.title,
    required this.status,
    required this.projectName,
    required this.clientName,
    required this.siteName,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.jobs,
  });

  final String title;
  final String status;
  final String projectName;
  final String clientName;
  final String siteName;
  final String description;
  final String startDate;
  final String endDate;
  final List<EmployeeProjectJobItem> jobs;
}

final class EmployeeProjectJobItem {
  const EmployeeProjectJobItem({
    required this.title,
    required this.status,
    required this.earning,
    required this.location,
    required this.schedule,
    required this.actionLabel,
  });

  final String title;
  final String status;
  final String earning;
  final String location;
  final String schedule;
  final String actionLabel;
}
