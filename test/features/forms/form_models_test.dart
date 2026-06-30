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
    expect(form.templateFormId, 99);
  });

  test('FormSummary reads project type installation and created date', () {
    final form = FormSummary.fromJson({
      'id': 12,
      'form_name': 'Technician_Plumbing',
      'is_active': true,
      'project_type': {'name': 'Pre-Construction'},
      'installation_type': 'Construction Pipes Installation',
      'created_at': '2026-06-18T10:00:00Z',
    });

    expect(form.projectTypeLabel, 'Pre-Construction');
    expect(form.installationTypeLabel, 'Construction Pipes Installation');
    expect(form.createdAt, isNotNull);
  });

  test('FormSummary reads installation type id from nested object', () {
    final form = FormSummary.fromJson({
      'id': 13,
      'form_name': 'Technician_Plumbing',
      'installation_type': {'id': 7, 'name': 'Construction Pipes Installation'},
    });

    expect(form.installationTypeId, 7);
    expect(form.installationTypeLabel, 'Construction Pipes Installation');
  });

  test('FormSummary ignores nested template form installation type', () {
    final form = FormSummary.fromJson({
      'id': 14,
      'form_name': 'Site Inspection',
      'form': {
        'id': 99,
        'form_name': 'Site Inspection',
        'installation_type': {'id': 5, 'name': 'Door Installation'},
      },
    });

    expect(form.installationTypeId, isNull);
    expect(form.templateFormId, 99);
  });

  test('FormSummary reads installation type id from project_type', () {
    final form = FormSummary.fromJson({
      'id': 15,
      'form_name': 'Door checklist',
      'project_type': {
        'id': 3,
        'name': 'Installation',
        'installation_type': {'id': 9, 'name': 'Door'},
      },
    });

    expect(form.installationTypeId, 9);
  });

  test('readInstallationTypeId reads id from installation-type API row', () {
    expect(
      readInstallationTypeId({
        'id': 4,
        'installation_type': 'Industrial - Installation',
      }),
      4,
    );
  });
}
