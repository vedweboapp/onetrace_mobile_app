import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';

void main() {
  const vendorsListResponse = <String, dynamic>{
    'success': true,
    'message': 'Data fetched successfully',
    'data': [
      {
        'id': 2,
        'name': 'Vendor one',
        'email': 'naina@weboappdiscovery.com',
        'phone': '+917901968155',
        'type': {
          'id': 2,
          'name': 'Transport',
          'bg_color': '#DBEAFE',
          'text_color': '#1E40AF',
        },
        'addresses': [
          {
            'id': 3,
            'address_line_1': '123shiv colonu',
            'address_line_2': null,
            'city': 'Potters Village',
            'state': 'Saint John Parish',
            'country': 'Antigua And Barbuda',
            'pincode': '160034',
            'is_primary': true,
          },
        ],
        'is_active': true,
      },
      {
        'id': 1,
        'name': 'SteelPeak Foundries',
        'email': 'r.henderson@steelpeak.com',
        'type': {
          'id': 1,
          'name': 'Raw Material',
        },
        'addresses': [],
        'is_active': true,
      },
    ],
    'pagination': {
      'total_records': 2,
      'total_pages': 1,
      'current_page': 1,
      'page_size': 20,
    },
  };

  test('parses vendors list with nested type object', () {
    final root = readApiMap(vendorsListResponse);
    final rows = readApiRows(root);
    final vendors = rows.map(VendorModel.fromJson).toList();

    expect(vendors, hasLength(2));
    expect(vendors[0].id, '2');
    expect(vendors[0].name, 'Vendor one');
    expect(vendors[0].typeId, 2);
    expect(vendors[0].typeName, 'Transport');
    expect(vendors[0].addresses.single.city, 'Potters Village');

    expect(vendors[1].id, '1');
    expect(vendors[1].typeName, 'Raw Material');
  });

  test('builds POST payload matching backend contract', () {
    final payload = VendorWritePayload.build(
      name: 'Testing',
      email: 'test@yopmail.coom',
      phone: '+919876543219',
      type: 2,
      addresses: [
        VendorAddressModel(
          addressLine1: 'Abhi Homes',
          addressLine2: 'Sector 20',
          city: 'Panchkula',
          state: 'Punjab',
          country: 'India',
          pincode: '160104',
          latitude: '30.6586844',
          longitude: '76.86383719999999',
          isPrimary: true,
        ),
      ],
    );

    expect(payload['name'], 'Testing');
    expect(payload['email'], 'test@yopmail.coom');
    expect(payload['phone'], '+919876543219');
    expect(payload['type'], 2);
    expect(payload['addresses'], hasLength(1));
    expect(payload['addresses'][0], {
      'address_line_1': 'Abhi Homes',
      'address_line_2': 'Sector 20',
      'city': 'Panchkula',
      'state': 'Punjab',
      'country': 'India',
      'pincode': '160104',
      'latitude': '30.6586844',
      'longitude': '76.86383719999999',
      'is_primary': true,
    });
  });

  test('builds multi-address vendor create payload from API example', () {
    final payload = VendorWritePayload.build(
      name: 'SteelPeak Foundries',
      email: 'rahul@yopmail.com',
      phone: '+1 (555) 123-4567',
      type: 1,
      addresses: [
        VendorAddressModel(
          addressLine1: '321 Ian Street',
          addressLine2: 'Andheri West',
          city: 'Tawang',
          state: 'Arunachal Pradeshsss',
          country: 'Indiasss',
          pincode: '400053',
          latitude: '27.5866',
          longitude: '91.8650',
          isPrimary: true,
        ),
        VendorAddressModel(
          addressLine1: 'Plot No. 12',
          addressLine2: 'Industrial Area',
          city: 'Mumbai',
          state: 'Maharashtra',
          country: 'India',
          pincode: '400001',
          latitude: '19.0760',
          longitude: '72.8777',
          isPrimary: false,
        ),
      ],
    );

    expect(payload['type'], 1);
    expect(payload['addresses'], hasLength(2));
    expect(payload['addresses'][0]['is_primary'], isTrue);
    expect(payload['addresses'][1]['is_primary'], isFalse);
    expect(payload['addresses'][0]['address_line_2'], 'Andheri West');
    expect(payload['addresses'][1]['latitude'], '19.0760');
  });

  test('builds vendor-type create payload', () {
    final payload = VendorTypeWritePayload.build(
      name: 'Transport',
      bgColor: '#DBEAFE',
      textColor: '#1E40AF',
    );

    expect(payload['name'], 'Transport');
    expect(payload['bg_color'], '#DBEAFE');
    expect(payload['text_color'], '#1E40AF');
    expect(payload['is_active'], isTrue);
  });

  test('parses created vendor from list-shaped POST response', () {
    const createResponse = <String, dynamic>{
      'success': true,
      'message': 'Data fetched successfully',
      'data': [
        {
          'id': 3,
          'name': 'Testing',
          'email': 'test@yopmail.coom',
          'phone': '+919876543219',
          'type': {'id': 2, 'name': 'Transport'},
          'addresses': [
            {
              'id': 4,
              'address_line_1': 'Abhi Homes',
              'city': 'Panchkula',
              'is_primary': true,
            },
          ],
          'is_active': true,
        },
        {
          'id': 2,
          'name': 'Vendor one',
          'email': 'naina@weboappdiscovery.com',
        },
      ],
    };

    final body = readApiMutationEntityBody(
      readApiMap(createResponse),
      matchPayload: {
        'name': 'Testing',
        'email': 'test@yopmail.coom',
        'type': 2,
      },
    );
    final vendor = VendorModel.fromJson(body);

    expect(vendor.id, '3');
    expect(vendor.name, 'Testing');
    expect(vendor.typeName, 'Transport');
  });
}
