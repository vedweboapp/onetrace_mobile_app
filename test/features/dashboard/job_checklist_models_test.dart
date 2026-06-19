import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

void main() {
  test('JobChecklistRead parses API checklists payload', () {
    final checklists = JobChecklistRead.tryFromMap({
      'is_marked': false,
      'items': [
        {
          'id': 1,
          'title': 'Pre-Installation Inspection',
          'sequence': 1,
          'is_required': true,
          'is_checked': false,
          'checked_at': null,
        },
        {
          'id': 2,
          'title': 'Be carefull',
          'sequence': 2,
          'is_required': true,
          'is_checked': true,
          'checked_at': '2026-06-18T06:36:31.966417Z',
        },
      ],
    });

    expect(checklists, isNotNull);
    expect(checklists!.isMarked, isFalse);
    expect(checklists.items, hasLength(2));
    expect(checklists.items.first.title, 'Pre-Installation Inspection');
    expect(checklists.items.last.isChecked, isTrue);
  });

  test('JobChecklistRead toWriteList matches PUT /jobs/{id}/ contract', () {
    final checklists = JobChecklistRead.tryFromMap({
      'is_marked': false,
      'items': [
        {
          'id': 1,
          'title': 'Pre-Installation Inspection',
          'sequence': 1,
          'is_required': true,
          'is_checked': true,
        },
      ],
    });

    expect(checklists, isNotNull);
    final writeList = checklists!.toWriteList();
    expect(writeList, isA<List<Map<String, dynamic>>>());
    expect(writeList.single['checklist_id'], 1);
    expect(writeList.single['is_checked'], isTrue);
    expect(writeList.single.containsKey('id'), isFalse);
    expect(writeList.single.containsKey('is_marked'), isFalse);
  });

  test('JobRead prefers job_status over pin_status_name for display', () {
    final job = JobRead.tryFromMap({
      'id': 6,
      'title': 'Test',
      'pin_status_name': 'Completed',
      'job_status': {
        'id': 1,
        'status_name': 'To Do',
      },
    });

    expect(job, isNotNull);
    expect(job!.displayStatus, 'To Do');
  });
}
