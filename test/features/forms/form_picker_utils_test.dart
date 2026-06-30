import 'package:flutter_test/flutter_test.dart';
import 'package:red5/features/forms/data/form_models.dart';
import 'package:red5/features/forms/data/form_picker_utils.dart';

void main() {
  test('matchingInstallationType keeps only project_forms with same id', () {
    final forms = [
      FormSummary.fromJson({
        'id': 1,
        'form_name': 'Form A',
        'installation_type': {'id': 7, 'name': 'Type A'},
      }),
      FormSummary.fromJson({
        'id': 2,
        'form_name': 'Form B',
        'installation_type': {'id': 8, 'name': 'Type B'},
      }),
      FormSummary.fromJson({
        'id': 3,
        'form_name': 'Form C',
        'installation_type_id': 7,
      }),
    ];

    final filtered = forms.matchingInstallationType(7);
    expect(filtered.map((form) => form.id), [1, 3]);
  });

  test('matchingInstallationType returns empty when pin type id is null', () {
    final forms = [
      FormSummary.fromJson({'id': 1, 'form_name': 'Form A'}),
      FormSummary.fromJson({'id': 2, 'form_name': 'Form B'}),
    ];

    expect(forms.matchingInstallationType(null), isEmpty);
  });

  test('matchingInstallationType excludes project_forms without installation type',
      () {
    final forms = [
      FormSummary.fromJson({
        'id': 1,
        'form_name': 'Untyped form',
      }),
      FormSummary.fromJson({
        'id': 2,
        'form_name': 'Typed form',
        'installation_type': {'id': 7, 'name': 'Type A'},
      }),
    ];

    final filtered = forms.matchingInstallationType(7);
    expect(filtered.map((form) => form.id), [2]);
  });

  test('matchingInstallationType reads installation type from project_type', () {
    final forms = [
      FormSummary.fromJson({
        'id': 4,
        'form_name': 'Door form',
        'project_type': {
          'id': 2,
          'name': 'Install',
          'installation_type': {'id': 7, 'name': 'Door install'},
        },
      }),
    ];

    expect(forms.matchingInstallationType(7).map((form) => form.id), [4]);
    expect(forms.matchingInstallationType(8), isEmpty);
  });
}
