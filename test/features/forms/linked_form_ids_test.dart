import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/forms/data/linked_form_ids.dart';

void main() {
  test('readLinkedTemplateFormIds reads int list and singular form', () {
    expect(
      readLinkedTemplateFormIds({
        'form': 5,
        'forms': [10, 11],
        'form_ids': [12],
      }),
      containsAll([5, 10, 11, 12]),
    );
  });

  test('readLinkedTemplateFormIds reads project_form_id rows', () {
    expect(
      readLinkedTemplateFormIds({
        'forms': [
          {'project_form_id': 18, 'job_form_id': 14},
          {'project_form_id': 20, 'job_form_id': 15},
        ],
      }),
      [18, 20],
    );
  });
}
