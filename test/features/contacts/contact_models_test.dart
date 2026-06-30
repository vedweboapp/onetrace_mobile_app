import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/features/contacts/data/contact_models.dart';

void main() {
  const vendorContactsResponse = <String, dynamic>{
    'success': true,
    'data': [
      {
        'id': 7,
        'name': 'Vendor Contact',
        'email': 'vendor.contact@example.com',
        'phone': '+919876543210',
        'contact_type': 'vendor',
        'vendor': {'id': 4, 'name': 'Testing'},
        'address_line_1': '12 Main St',
        'city': 'Panchkula',
        'state': 'Punjab',
        'country': 'India',
        'pincode': '160104',
        'is_active': true,
      },
    ],
    'pagination': {
      'total_records': 1,
      'total_pages': 1,
      'current_page': 1,
      'page_size': 20,
    },
  };

  test('parses vendor contact rows from list envelope', () {
    final root = readApiMap(vendorContactsResponse);
    final rows = readApiRows(root);
    final contact = ContactModel.fromJson(rows.single);

    expect(contact.id, '7');
    expect(contact.contactName, 'Vendor Contact');
    expect(contact.contactType, 'vendor');
    expect(contact.city, 'Panchkula');
    expect(contact.postalCode, '160104');
  });

  test('reads postal code from nested addresses on detail payloads', () {
    final contact = ContactModel.fromJson({
      'id': 4,
      'name': 'Vagita',
      'email': 'vagita@mailinator.com',
      'phone': '+918988988989',
      'addresses': [
        {
          'address_line_1': '23 Paskal Shopping Center',
          'city': 'Kota Bandung',
          'state': 'Jawa Barat',
          'country': 'Indonesia',
          'pincode': '40241',
          'is_primary': true,
        },
      ],
    });

    expect(contact.postalCode, '40241');
    expect(contact.city, 'Kota Bandung');
    expect(contact.addressLine1, '23 Paskal Shopping Center');
  });

  test('prefers flat pincode when both flat and nested addresses exist', () {
    final contact = ContactModel.fromJson({
      'id': 1,
      'name': 'Rohan Sharma',
      'pincode': '07728',
      'addresses': [
        {'pincode': '00000', 'city': 'Ignored'},
      ],
    });

    expect(contact.postalCode, '07728');
  });
}
