import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';

void main() {
  test('parseFormFieldOptions reads string list options', () {
    final options = parseFormFieldOptions({
      'options': ['Good one', 'Average', 'Poor'],
    });

    expect(options, ['Good one', 'Average', 'Poor']);
  });

  test('parseFormFieldOptions reads labeled option objects', () {
    final options = parseFormFieldOptions({
      'options': [
        {'label': 'Good one', 'value': 'good_one'},
        {'name': 'Average', 'id': 'avg'},
      ],
    });

    expect(options, ['Good one', 'Average']);
  });

  test('parseFormFieldOptions reads properties.choices', () {
    final options = parseFormFieldOptions({
      'properties': {
        'choices': 'Good one, Average, Poor',
      },
    });

    expect(options, ['Good one', 'Average', 'Poor']);
  });
}
