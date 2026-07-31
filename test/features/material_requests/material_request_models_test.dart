import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';

void main() {
  test('MaterialRequestRead parses operative list payload', () {
    final parsed = MaterialRequestRead.tryFromMap({
      'id': 22,
      'job_worker': {
        'id': 14,
        'first_name': 'Anirudh',
        'last_name': 'Jain',
      },
      'jobs': [
        {
          'id': 167,
          'serial_number': 'JB086',
          'client_name': 'jeen',
        },
      ],
      'status': {
        'id': 68,
        'name': 'PENDING',
        'bg_colour': '#a77408',
        'text_colour': '#ffffff',
      },
      'material_request_line': [
        {
          'id': 12,
          'item': 19,
          'item_name': 'Tip',
          'item_sku': 'tip12',
          'requested_quantity': 2,
          'dispatched_quantity': 0,
          'returned_quantity': 0,
          'job': 167,
        },
        {
          'id': 13,
          'item': 34,
          'item_name': 'Heavy Duty Wall Bracket',
          'requested_quantity': 1,
          'dispatched_quantity': 0,
          'returned_quantity': 0,
          'job': 167,
        },
      ],
      'request_number': 'MR021',
      'requested_date': '2026-07-28',
    });

    expect(parsed, isNotNull);
    expect(parsed!.id, 22);
    expect(parsed.requestNumber, 'MR021');
    expect(parsed.status, MaterialRequestStatus.pending);
    expect(parsed.statusId, 68);
    expect(parsed.workerId, 14);
    expect(parsed.workerName, 'Anirudh Jain');
    expect(parsed.jobs, hasLength(1));
    expect(parsed.jobs.first.serialNumber, 'JB086');
    expect(parsed.lines, hasLength(2));
    expect(parsed.lines.first.pendingQuantity, 2);

    final listItem = parsed.toListItem();
    expect(listItem.requestCode, 'MR021');
    expect(listItem.jobCode, 'JB086');
    expect(listItem.itemCount, 2);
    expect(listItem.statusLabel, 'PENDING');

    final detail = parsed.toDetail();
    expect(detail.items, hasLength(2));
    expect(detail.items.first.pendingLabel, '2');
    expect(detail.dispatchItems, isEmpty);
  });

  test('MaterialRequestRead maps DISPATCHED status and dispatch items', () {
    final parsed = MaterialRequestRead.tryFromMap({
      'id': 14,
      'request_number': 'MR013',
      'job_worker': {'id': 14, 'first_name': 'Anirudh', 'last_name': 'Jain'},
      'jobs': [
        {
          'id': 159,
          'serial_number': 'JB078',
          'project_name': 'Quantom jump pod',
        },
      ],
      'status': {'id': 72, 'name': 'DISPATCHED'},
      'material_request_line': [
        {
          'id': 10,
          'item': 19,
          'item_name': 'Tip',
          'requested_quantity': 1,
          'dispatched_quantity': 1,
          'returned_quantity': 0,
          'job': 159,
        },
      ],
    });

    expect(parsed!.status, MaterialRequestStatus.dispatched);
    expect(parsed.toDetail().dispatchItems, hasLength(1));
    expect(parsed.toListItem().jobCode, 'JB078');
  });
}
