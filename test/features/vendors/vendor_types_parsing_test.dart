import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';

void main() {
  const vendorTypeListResponse = <String, dynamic>{
    'success': true,
    'message': 'Data fetched successfully',
    'data': [
      {
        'id': 2,
        'name': 'Transport',
        'bg_color': '#DBEAFE',
        'text_color': '#1E40AF',
        'is_active': true,
      },
      {
        'id': 1,
        'name': 'Raw Material',
        'bg_color': '#FEF3C7',
        'text_color': '#92400E',
        'is_active': true,
      },
    ],
    'pagination': {
      'total_records': 2,
      'total_pages': 1,
      'current_page': 1,
      'page_size': 100,
      'next': null,
      'previous': null,
    },
  };

  test('parses vendor types from standard list envelope', () {
    final root = readApiMap(vendorTypeListResponse);
    final rows = readApiRows(root);
    final types = rows.map(VendorTypeOption.fromJson).toList();

    expect(types, hasLength(2));
    expect(types[0].id, 2);
    expect(types[0].name, 'Transport');
    expect(types[0].bgColor, '#DBEAFE');
    expect(types[0].textColor, '#1E40AF');
    expect(types[1].id, 1);
    expect(types[1].name, 'Raw Material');
  });

  test('readApiMap decodes JSON string bodies', () {
    const encoded =
        '{"success":true,"data":[{"id":3,"name":"Services"}],"pagination":{}}';
    final root = readApiMap(encoded);
    final rows = readApiRows(root);
    final type = VendorTypeOption.fromJson(rows.single);

    expect(type.id, 3);
    expect(type.name, 'Services');
  });
}
