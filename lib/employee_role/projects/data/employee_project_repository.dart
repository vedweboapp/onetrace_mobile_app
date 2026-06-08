import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';

final employeeProjectRepositoryProvider = Provider<EmployeeProjectRepository>((
  ref,
) {
  return const EmployeeProjectRepository();
});

final class EmployeeProjectRepository {
  const EmployeeProjectRepository();

  Future<EmployeeProjectDetail> fetchProjectDetail({
    String? projectName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final title = (projectName?.trim().isNotEmpty ?? false)
        ? projectName!.trim()
        : 'Foundation Reinforcement';

    return EmployeeProjectDetail(
      title: title,
      status: title.toLowerCase().contains('hvac')
          ? 'PROJECT COMPLETED'
          : 'PROJECT ACTIVE',
      projectName: '$title - Phase 2',
      clientName: title.toLowerCase().contains('solar')
          ? 'GreenEnergy Solutions Ltd.'
          : 'City Infra Group Ltd.',
      siteName: title.toLowerCase().contains('solar')
          ? 'North Ridge Substation'
          : 'West-End Extension Block B',
      description:
          'Comprehensive reinforcement of existing concrete foundations using high-tensile steel rebars and epoxy injection. The project includes soil stabilization and moisture barrier installation across the entire Block B basement perimeter.',
      startDate: 'Sep 15, 2023',
      endDate: title.toLowerCase().contains('solar')
          ? 'Nov 12, 2023'
          : 'Oct 24, 2023',
      jobs: const [
        EmployeeProjectJobItem(
          title: 'Install fire alarm units',
          status: 'IN PROGRESS',
          earning: '\u00A364.00',
          location: 'Riverside Tower · Floor 7',
          schedule: 'Today · 10:00 AM - 4:30 PM',
          actionLabel: 'Continue Job',
        ),
        EmployeeProjectJobItem(
          title: 'Deliver copper pipes',
          status: 'UPCOMING',
          earning: '\u00A342.50',
          location: 'Metro Mall · Loading Bay',
          schedule: 'Tomorrow · 8:30 AM',
          actionLabel: 'View Details',
        ),
        EmployeeProjectJobItem(
          title: 'Concrete quality check',
          status: 'PENDING',
          earning: '\u00A355.00',
          location: 'Greenfield Site',
          schedule: 'Friday · 9:00 AM',
          actionLabel: 'View Details',
        ),
      ],
    );
  }
}
