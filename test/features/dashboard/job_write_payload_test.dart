import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/data/job_write_payload.dart';

void main() {
  test('JobWritePayload sends multiple forms for create job', () {
    final payload = JobWritePayload.build(
      title: 'Site visit',
      formIds: [18, 20, 22],
    );

    expect(payload['forms'], [18, 20, 22]);
    expect(payload.containsKey('form_ids'), isFalse);
    expect(payload.containsKey('form'), isFalse);
  });

  test('JobWritePayload.buildFromJobRead uses forms and trims title', () {
    final job = JobRead(
      id: 6,
      title: '  Site visit  ',
      formIds: const [18, 20],
      jobMeta: const {'total': 25},
      raw: const {},
    );

    final payload = JobWritePayload.buildFromJobRead(job);

    expect(payload['title'], 'Site visit');
    expect(payload['forms'], [18, 20]);
    expect(payload.containsKey('form'), isFalse);
    expect(payload['job_meta'], const {'total': 25});
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
      JobRead.linkedFormTemplateIds({'forms': [10, 11]}),
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
