import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/forms/data/form_models.dart';

void main() {
  test('FormSummary.fromJson reads project-forms list rows', () {
    final form = FormSummary.fromJson({
      'id': 10,
      'form_name': 'Safety Checklist',
      'is_active': true,
      'project': 4,
    });

    expect(form.id, 10);
    expect(form.name, 'Safety Checklist');
    expect(form.isActive, isTrue);
  });

  test('FormSummary.fromJson falls back to nested form payload', () {
    final form = FormSummary.fromJson({
      'project_form_id': 11,
      'form': {
        'id': 99,
        'name': 'Ignored nested id',
        'form_name': 'Site Inspection',
      },
    });

    expect(form.id, 11);
    expect(form.name, 'Site Inspection');
  });
}
