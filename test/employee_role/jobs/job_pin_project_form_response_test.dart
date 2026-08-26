import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

void main() {
  final sampleJob = <String, dynamic>{
    'id': 470,
    'job_serial_number': 'JB442',
    'description': 'this dorr survey job',
    'project': {'id': 61, 'name': 'Hamaer Construction site'},
    'client': {'id': 24, 'name': 'steve'},
    'site': {
      'id': 19,
      'site_name': 'Clay',
      'address_line_1': 'Clisson, France',
    },
    'assigned_workers': [
      {
        'id': 39,
        'name': 'Tora Seon',
        'email': 'tora@mailinator.com',
        'role_name': 'Technician',
      },
    ],
    'job_status': {
      'id': 1,
      'status_name': 'To Do',
      'bg_colour': '#E5E7EB',
      'text_colour': '#111827',
    },
    'forms': <dynamic>[],
    'checklists': {
      'is_marked': false,
      'items': [
        {
          'id': 25,
          'title': 'Ch11',
          'file':
              'http://110.225.254.51:5050/backend/media/checklist_templates/image_40.png',
          'sequence': 1,
          'is_required': true,
          'is_checked': false,
          'concentric_point': false,
          'checked_at': null,
          'is_marked': false,
        },
      ],
    },
    'levels': [
      {
        'id': 73,
        'name': '1735906155',
        'order': 1,
        'drawing_file':
            'http://110.225.254.51:5050/backend/media/drawings/1735906155.webp',
        'plots': [
          {
            'id': 147,
            'name': 'floor 1',
            'pins': [
              {
                'id': 830,
                'job_pin_id': 187,
                'project_form': {
                  'id': 83,
                  'name': 'Door survey Form',
                  'submission_id': null,
                  'submission_status': null,
                },
                'qr_code': null,
                'location': '6',
                'x_coordinate': 28.981481,
                'y_coordinate': 33.518519,
                'item_detail': {'id': 520, 'name': 'Fire Hydrant'},
                'status_detail': {
                  'status_name': 'To Do',
                  'bg_colour': '#E5E7EB',
                  'text_colour': '#111827',
                },
              },
            ],
          },
        ],
      },
    ],
    'job_category': 'projectjob',
    'job_schedule_detail': {
      'id': 72,
      'start_at': '2026-08-27T03:30:00Z',
      'end_at': '2026-08-27T07:30:00Z',
    },
    'total_earning': 650.0,
  };

  test('JobRead maps empty forms + pin project_form + assigned_workers', () {
    final job = JobRead.tryFromMap(sampleJob);
    expect(job, isNotNull);
    expect(job!.id, 470);
    expect(job.jobSerialNumber, 'JB442');
    expect(job.title, 'JB442');
    expect(job.projectName, 'Hamaer Construction site');
    expect(job.clientName, 'steve');
    expect(job.siteName, 'Clay');
    expect(job.workerName, 'Tora Seon');
    expect(job.assignedWorker, 39);
    expect(job.formIds, [83]);
    expect(job.form, 83);
    expect(job.displayStatus, 'To Do');
    expect(job.checklists?.items, hasLength(1));
    expect(job.checklists?.items.first.title, 'Ch11');
    expect(job.scheduleDetail?.startAt, isNotNull);
  });

  test('pin project_form drives drawing pin + form assignments', () {
    final levels = parseEmployeeJobDrawingLevels(sampleJob['levels']);
    expect(levels, hasLength(1));
    final pin = levels.first.plots.first.pins.first;
    expect(pin.id, 830);
    expect(pin.jobPinId, 187);
    expect(pin.projectFormId, 83);
    expect(pin.projectFormName, 'Door survey Form');
    expect(pin.hasForm, isTrue);
    expect(pin.qrCodeFieldPresent, isTrue);
    expect(pin.hasQrCode, isFalse);

    final tasks = collectPinFormTasks(levels);
    expect(tasks, hasLength(1));
    expect(tasks.first.formId, 83);
    expect(tasks.first.jobPinId, 187);

    final assignments = JobFormAssignment.listFromJobRaw(sampleJob);
    expect(assignments, hasLength(1));
    expect(assignments.first.formId, 83);
    expect(assignments.first.jobFormId, 187);

    final linked = JobLinkedFormSummary.listFromJobRaw(sampleJob);
    expect(linked, hasLength(1));
    expect(linked.first.formId, 83);
    expect(linked.first.jobFormId, 187);
    expect(linked.first.name, 'Door survey Form');
  });
}
