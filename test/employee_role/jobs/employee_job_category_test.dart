import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

void main() {
  group('EmployeeJobCategory', () {
    test('parses projectjob and servicejob', () {
      expect(
        EmployeeJobCategory.fromApi('projectjob'),
        EmployeeJobCategory.project,
      );
      expect(
        EmployeeJobCategory.fromApi('servicejob'),
        EmployeeJobCategory.service,
      );
      expect(
        EmployeeJobCategory.fromApi(null),
        EmployeeJobCategory.unknown,
      );
    });

    test('usesDesignsWorkflow is false for service even with levels', () {
      const job = EmployeeJobDetail(
        id: 1,
        title: 'JB067',
        currentStatus: 'TO DO',
        project: '—',
        client: 'jeen',
        siteContact: '',
        block: 'Site',
        plot: '',
        description: 'service',
        items: [],
        safetyChecklist: [],
        jobCategory: EmployeeJobCategory.service,
        levels: [],
      );

      expect(job.usesDesignsWorkflow, isFalse);
      expect(job.jobCategory.isService, isTrue);
    });

    test('usesDesignsWorkflow follows drawing hierarchy for project jobs', () {
      const emptyProject = EmployeeJobDetail(
        id: 2,
        title: 'JB068',
        currentStatus: 'TO DO',
        project: 'Quantom',
        client: 'jeen',
        siteContact: '',
        block: 'Site',
        plot: '',
        description: '',
        items: [],
        safetyChecklist: [],
        jobCategory: EmployeeJobCategory.project,
        levels: [],
      );

      expect(emptyProject.usesDesignsWorkflow, isFalse);
      expect(emptyProject.jobCategory.isProject, isTrue);
    });
  });
}
