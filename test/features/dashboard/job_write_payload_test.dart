import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/data/job_write_payload.dart';

void main() {
  test('JobWritePayload sends project_form_id rows for project jobs', () {
    final payload = JobWritePayload.build(
      title: 'Site visit',
      project: 12,
      formIds: [18, 20, 22],
    );

    expect(payload['forms'], [
      {'project_form_id': 18},
      {'project_form_id': 20},
      {'project_form_id': 22},
    ]);
    expect(payload.containsKey('form_ids'), isFalse);
    expect(payload.containsKey('form'), isFalse);
  });

  test('JobWritePayload sends dynamic_form_id rows for service jobs', () {
    final payload = JobWritePayload.build(
      title: 'Service call',
      formIds: [34, 72],
    );

    expect(payload['forms'], [
      {'dynamic_form_id': 34},
      {'dynamic_form_id': 72},
    ]);
  });

  test('JobWritePayload.buildFromJobRead uses dynamic_form_id from job raw', () {
    final job = JobRead(
      id: 390,
      title: '  Service job  ',
      formIds: const [34, 72],
      jobMeta: const {'total': 25},
      raw: const {
        'forms': [
          {
            'job_form_id': 50,
            'dynamic_form_id': 34,
            'name': 'Project 2',
          },
          {
            'job_form_id': 51,
            'dynamic_form_id': 72,
            'name': 'water pump',
          },
        ],
      },
    );

    final payload = JobWritePayload.buildFromJobRead(job);

    expect(payload['title'], 'Service job');
    expect(payload['forms'], [
      {'dynamic_form_id': 34, 'job_form_id': 50},
      {'dynamic_form_id': 72, 'job_form_id': 51},
    ]);
  });

  test('JobWritePayload.buildFromJobRead uses project_form_id from job raw', () {
    final job = JobRead(
      id: 6,
      title: 'Project job',
      project: 9,
      formIds: const [18, 20],
      raw: const {
        'forms': [
          {'job_form_id': 14, 'project_form_id': 18},
          {'job_form_id': 15, 'project_form_id': 20},
        ],
      },
    );

    final payload = JobWritePayload.buildFromJobRead(job);

    expect(payload['forms'], [
      {'project_form_id': 18, 'job_form_id': 14},
      {'project_form_id': 20, 'job_form_id': 15},
    ]);
  });

  test('JobWritePayload.buildCompositeJobMeta matches create job contract', () {
    final meta = JobWritePayload.buildCompositeJobMeta(
      compositeItems: [
        {
          'id': 12,
          'quantity': 1,
          'name': 'Window Apoxi Glue',
          'group': {'id': 3, 'name': 'Window Legends'},
          'amount': 25,
        },
      ],
      total: 25,
    );

    expect(meta['total'], 25);
    expect(meta['composite_items'], hasLength(1));
  });

  test('JobRead.linkedFormTemplateIds reads forms[] id list', () {
    expect(
      JobRead.linkedFormTemplateIds({
        'forms': [10, 11],
      }),
      [10, 11],
    );
  });

  test('JobRead.linkedFormTemplateIds reads forms[] project_form_id rows', () {
    final ids = JobRead.linkedFormTemplateIds({
      'form': 5,
      'forms': [
        {'job_form_id': 14, 'project_form_id': 18},
        {'job_form_id': 15, 'project_form_id': 20},
      ],
    });

    expect(ids, containsAll([5, 18, 20]));
    expect(ids.length, 3);
  });

  test('JobRead.linkedFormTemplateIds prefers dynamic_form_id rows', () {
    final ids = JobRead.linkedFormTemplateIds({
      'forms': [
        {'job_form_id': 50, 'dynamic_form_id': 34},
        {'job_form_id': 51, 'dynamic_form_id': 72},
      ],
    });

    expect(ids, [34, 72]);
  });

  test('JobWritePayload includes optional salesperson', () {
    final payload = JobWritePayload.build(
      title: 'Site visit',
      assignedWorker: 2,
      salesperson: 5,
    );

    expect(payload['assigned_worker'], 2);
    expect(payload['salesperson'], 5);
  });

  test('JobWritePayload omits salesperson when not set', () {
    final payload = JobWritePayload.build(
      title: 'Site visit',
      assignedWorker: 2,
    );

    expect(payload.containsKey('salesperson'), isFalse);
  });
}
