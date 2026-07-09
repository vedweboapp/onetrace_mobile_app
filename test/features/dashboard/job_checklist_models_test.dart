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
          'concentric_point': false,
        },
        {
          'id': 2,
          'title': 'Pipe Inspection',
          'sequence': 2,
          'is_required': true,
          'is_checked': false,
          'concentric_point': true,
        },
      ],
    });

    expect(checklists, isNotNull);
    final writeList = checklists!.toWriteList();
    expect(writeList, isA<List<Map<String, dynamic>>>());
    expect(writeList.first['checklist_id'], 1);
    expect(writeList.first['is_checked'], isTrue);
    expect(writeList.first['concentric_point'], isFalse);
    expect(writeList.last['checklist_id'], 2);
    expect(writeList.last['concentric_point'], isTrue);
    expect(writeList.first.containsKey('id'), isFalse);
    expect(writeList.first.containsKey('is_marked'), isFalse);
  });

  test('JobChecklistItemRead treats missing concentric_point as required', () {
    final item = JobChecklistItemRead.tryFromMap({
      'id': 4,
      'title': 'Safety Checklist',
      'sequence': 1,
      'is_required': true,
      'is_checked': false,
    });

    expect(item, isNotNull);
    expect(item!.requiresConcentricPoint, isTrue);
    expect(item.concentricPoint, isFalse);
  });

  test('JobChecklistItemRead respects explicit concentric_point false', () {
    final item = JobChecklistItemRead.tryFromMap({
      'id': 1,
      'title': 'Fire Door Check',
      'sequence': 1,
      'is_required': true,
      'is_checked': true,
      'concentric_point': false,
    });

    expect(item, isNotNull);
    expect(item!.requiresConcentricPoint, isFalse);
  });

  test('JobChecklistRead parses checklist file URLs from API payload', () {
    final checklists = JobChecklistRead.tryFromMap({
      'is_marked': true,
      'items': [
        {
          'id': 1,
          'title': 'Fire Door Check',
          'file':
              'http://192.168.1.11:8006/backend/media/checklist_templates/fire_door_check.pdf',
          'sequence': 1,
          'is_required': true,
          'is_checked': true,
          'is_marked': true,
          'concentric_point': false,
        },
        {
          'id': 3,
          'title': 'Valve Testing',
          'file': null,
          'sequence': 3,
          'is_required': false,
          'is_checked': false,
        },
      ],
    });

    expect(checklists, isNotNull);
    expect(checklists!.items.first.hasFile, isTrue);
    expect(checklists.items.first.file, contains('fire_door_check.pdf'));
    expect(checklists.items.last.hasFile, isFalse);
    expect(checklists.items.first.isMarked, isTrue);
    expect(checklists.items.first.concentricPoint, isFalse);
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
