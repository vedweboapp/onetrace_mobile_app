import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

final employeeJobRepositoryProvider = Provider<EmployeeJobRepository>((ref) {
  return const EmployeeJobRepository();
});

final class EmployeeJobRepository {
  const EmployeeJobRepository();

  Future<List<EmployeeJobSummary>> fetchJobs() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return const [
      EmployeeJobSummary(
        id: 500,
        title: 'Install fire alarm units',
        status: EmployeeJobStatus.inProgress,
        earning: '\u00A364.00',
        location: 'Riverside Tower · Floor 7',
        schedule: 'Today · 10:00 AM - 4:30 PM',
        primaryActionLabel: 'Continue Job',
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
      EmployeeJobSummary(
        id: 503,
        title: 'Submit final site report',
        status: EmployeeJobStatus.completed,
        earning: '\u00A328.00',
        location: 'North Construction Office',
        schedule: 'Yesterday · 5:00 PM',
        primaryActionLabel: 'View Details',
      ),
    ];
  }

  Future<EmployeeJobDetail> fetchJobDetail({int? jobId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const EmployeeJobDetail(
      id: 501,
      title: 'Deliver copper pipes',
      currentStatus: 'UPCOMING',
      project: 'Commercial Building Upgrade',
      client: 'Metro Property Management',
      siteContact: '54687843546',
      block: 'Deliver copper pipes',
      plot: 'Deliver copper pipes',
      description:
          'Install and configure electrical panel at site location. Ensure all safety protocols are followed during the high-voltage setup.',
      materials: [
        EmployeeJobMaterial(
          name: 'Smoke Detectors',
          quantity: '10 units',
          iconName: 'detector',
        ),
        EmployeeJobMaterial(
          name: 'Wiring (FR Cable)',
          quantity: '50 meters',
          iconName: 'wire',
        ),
      ],
      safetyChecklist: [
        EmployeeSafetyChecklistItem(
          id: 'ppe',
          title: 'PPE gear inspected and worn',
          isChecked: true,
        ),
        EmployeeSafetyChecklistItem(
          id: 'area',
          title: 'Work area cordoned off',
        ),
        EmployeeSafetyChecklistItem(
          id: 'circuit',
          title: 'Circuit isolated and tested',
        ),
        EmployeeSafetyChecklistItem(
          id: 'tools',
          title: 'Tools inspected for defects',
        ),
      ],
    );
  }
}
/// ==================================================
///
/*
{
    "title": "title",
    "description": "des",
    "assigned_worker": 2,
    "start_date": "2026-05-02T13:05:00.000Z",

    "end_date": "2026-05-28T13:06:00.000Z",
    "comments": "comment",
    "job_status": 3,
    "client": 4,,m, ,
    "project": 3,
    "site": 16,
    "job_meta": {
        "section": {
            "name": "section"
        },
        "plot": {
            "name": "plot name",
            "plot_total": 5500,
            "group": 7,
            "composite_items": [
                {
                    "id": 17,
                    "quantity": 10
                }
            ]
        }
    }
}
* */