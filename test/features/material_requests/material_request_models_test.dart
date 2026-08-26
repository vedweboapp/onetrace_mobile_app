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

  test('MaterialDispatchRead parses operative dispatch payload', () {
    final parsed = MaterialDispatchRead.tryFromMap({
      'id': 15,
      'worker': {
        'job_worker_id': 189,
        'user_org_map_id': 12,
        'first_name': 'Kia',
        'last_name': 'Soni',
        'username': 'kia_94d7fa',
        'email': 'kia@mailinator.com',
      },
      'lines': [
        {
          'id': 28,
          'material_request_line': 26,
          'item': 108,
          'item_name': 'Safron',
          'item_sku': 'SKFRON2',
          'quantity': 2,
          'is_extra': false,
          'remarks': null,
          'pending_quantity': 2,
          'returned_quantity': 0,
        },
        {
          'id': 29,
          'material_request_line': null,
          'item': 97,
          'item_name': 'Putty Pads',
          'item_sku': 'PP-001',
          'quantity': 2,
          'is_extra': true,
          'remarks': null,
          'pending_quantity': 2,
          'returned_quantity': 0,
        },
      ],
      'dispatch_order_number': 'DISP014',
      'dispatch_date': '2026-08-06',
      'notes': 'testing notes',
      'material_request': 26,
      'organization': 1,
    });

    expect(parsed, isNotNull);
    expect(parsed!.id, 15);
    expect(parsed.code, 'DISP014');
    expect(parsed.materialRequestId, 26);
    expect(parsed.materialRequestCode, '26');
    expect(parsed.workerId, 12);
    expect(parsed.userOrgMapId, 12);
    expect(parsed.jobWorkerId, 189);
    expect(parsed.dispatchTo, 'Kia Soni');
    expect(parsed.notes, 'testing notes');
    expect(parsed.items, hasLength(2));
    expect(parsed.items.first.itemName, 'Safron');
    expect(parsed.items.first.sku, 'SKFRON2');
    expect(parsed.items.first.quantity, 2);
    expect(parsed.items.first.isExtra, isFalse);
    expect(parsed.items.last.isExtra, isTrue);
    expect(parsed.totalQuantity, 4);
  });

  test('MaterialReturnRequestRead parses operative return-request payload', () {
    final parsed = MaterialReturnRequestRead.tryFromMap({
      'id': 10,
      'request_number': 'RET-1785759401',
      'status': 'completed',
      'requested_at': '2026-08-03T12:16:41.741456Z',
      'completed_at': '2026-08-05T08:52:45.353317Z',
      'worker': {
        'job_worker_id': 185,
        'user_org_map_id': 12,
        'first_name': 'Kia',
        'last_name': 'Soni',
        'username': 'kia_94d7fa',
        'email': 'kia@mailinator.com',
      },
      'return_request_line': [
        {
          'id': 13,
          'dispatch_line': 19,
          'item': {
            'id': 109,
            'name': 'Safron Element',
            'sku': 'SKU2332',
          },
          'dispatch_quantity': 2,
          'quantity': 2,
          'return_type': 'unused',
          'reason': null,
        },
      ],
      'created_at': '2026-08-03T12:16:41.742010Z',
    });

    expect(parsed, isNotNull);
    expect(parsed!.id, 10);
    expect(parsed.code, 'RET-1785759401');
    expect(parsed.statusName, 'completed');
    expect(parsed.displayStatusLabel, 'Completed');
    expect(parsed.workerId, 12);
    expect(parsed.userOrgMapId, 12);
    expect(parsed.jobWorkerId, 185);
    expect(parsed.workerName, 'Kia Soni');
    expect(parsed.requestedDate, isNotNull);
    expect(parsed.itemCount, 1);
    expect(parsed.totalQuantity, 2);
    expect(parsed.items.single.itemName, 'Safron Element');
    expect(parsed.items.single.sku, 'SKU2332');
    expect(parsed.items.single.dispatchLineId, 19);
    expect(parsed.items.single.displayReturnType, 'Unused');
    expect(parsed.dispatchLineIds, {19});
  });
}
