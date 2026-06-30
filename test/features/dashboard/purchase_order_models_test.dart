import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/dashboard/data/purchase_order_models.dart';

void main() {
  group('PurchaseOrderListItem.fromJson', () {
    test('parses list row from purchase-orders API', () {
      final item = PurchaseOrderListItem.fromJson({
        'id': 1,
        'purchase_order_number': 'PO-2024-001',
        'vendor': {
          'id': 1,
          'name': 'SteelPeak Foundries',
          'email': 'r.henderson@steelpeak.com',
          'phone': '+1 (555) 123-4567',
        },
        'project': {'id': 11, 'name': 'Deharadun Project initiative -D2'},
        'project_name': 'Deharadun Project initiative -D2',
        'sub_total': '11635.00',
        'adjustment_amount': '0.00',
        'total_balance': '11635.00',
        'total': 11635,
        'issue_date': '2026-06-02',
        'due_date': '2026-07-02',
        'payment_terms': 'Net 30 Days',
        'status': 'draft',
        'created_at': '2026-06-25T06:08:47.205Z',
      });

      expect(item.id, '1');
      expect(item.purchaseOrderNumber, 'PO-2024-001');
      expect(item.vendorName, 'SteelPeak Foundries');
      expect(item.category, 'Deharadun Project initiative -D2');
      expect(item.amount, 11635);
      expect(item.status, PurchaseOrderListStatus.draft);
      expect(item.date, DateTime.parse('2026-06-02'));
    });
  });

  group('PurchaseOrderDetail.fromJson', () {
    test('parses detail with nested vendor and totals', () {
      final detail = PurchaseOrderDetail.fromJson({
        'id': 1,
        'purchase_order_number': 'PO-2024-001',
        'vendor': {'id': 1, 'name': 'SteelPeak Foundries'},
        'project_name': 'Deharadun Project initiative -D2',
        'issue_date': '2026-06-02',
        'due_date': '2026-07-02',
        'payment_terms': 'Net 30 Days',
        'status': 'draft',
        'adjustment_amount': '0.00',
        'total': 11635,
        'line_items': [
          {
            'product_name': 'Steel beam',
            'quantity': 2,
            'unit_price': '500.00',
            'total': '1000.00',
          },
        ],
      });

      expect(detail.id, '1');
      expect(detail.purchaseOrderNumber, 'PO-2024-001');
      expect(detail.vendorName, 'SteelPeak Foundries');
      expect(detail.projectName, 'Deharadun Project initiative -D2');
      expect(detail.status, PurchaseOrderDetailStatus.draft);
      expect(detail.grandTotalAmount, 11635);
      expect(detail.lineItems, hasLength(1));
      expect(detail.lineItems.first.productName, 'Steel beam');
      expect(detail.lineItems.first.qty, 2);
    });

    test('parses vendor id when vendor is a scalar FK', () {
      final detail = PurchaseOrderDetail.fromJson({
        'id': 3,
        'vendor': 1,
        'contact': 18,
        'project': 21,
        'total': 70,
        'due_date': '2026-06-26',
        'payment_terms': 'net_30',
        'composite_items': [],
      });

      expect(detail.vendorId, '1');
      expect(detail.contactId, '18');
      expect(detail.projectId, '21');
      expect(detail.vendorName, 'Vendor 1');
      expect(detail.contactPerson, 'Contact 18');
      expect(detail.projectName, 'Project 21');
    });

    test('parses detail with composite_items and bill_to/ship_to', () {
      final detail = PurchaseOrderDetail.fromJson({
        'id': 2,
        'vendor': {'id': 1, 'name': 'Vendor One'},
        'contact': {'id': 18, 'contact_name': 'Jane'},
        'project': {'id': 21, 'name': 'Project A'},
        'due_date': '2026-06-26',
        'payment_terms': 'net_30',
        'total': 70,
        'bill_to': {
          'address_line_1': 'abhi',
          'city': 'Andorra la Vella',
          'state': 'Andorra la Vella',
          'pincode': '098778',
          'country': 'Andorra',
        },
        'ship_to': {
          'address_line_1': 'Abhi Homes',
          'address_line_2': 'Sector 20',
          'city': 'Panchkula',
          'state': 'Punjab',
          'pincode': '160104',
          'country': 'India',
        },
        'vendor_notes': 'testing',
        'internal_notes': 'testinf1',
        'composite_items': [
          {
            'id': 29,
            'name': 'Iron Holding strips',
            'group': {'id': 7, 'name': 'Tata Group'},
            'quantity': 1,
            'amount': 70,
          },
        ],
      });

      expect(detail.vendorId, '1');
      expect(detail.contactId, '18');
      expect(detail.projectId, '21');
      expect(detail.paymentTerms, 'Net 30 Days');
      expect(detail.notes, 'testing');
      expect(detail.internalNotes, 'testinf1');
      expect(detail.grandTotalAmount, 70);
      expect(detail.lineItems, hasLength(1));
      expect(detail.lineItems.first.compositeItemId, 29);
      expect(detail.lineItems.first.groupId, 7);
      expect(detail.lineItems.first.amount, 70);
      expect(detail.billingAddress.city, 'Andorra la Vella');
      expect(detail.shippingAddress.city, 'Panchkula');
    });
  });
}
