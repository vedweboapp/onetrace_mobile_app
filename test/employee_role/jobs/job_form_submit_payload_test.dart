import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

void main() {
  test('JobFormSubmitPayload matches submit-form API contract', () {
    const payload = JobFormSubmitPayload(
      jobFormId: 6,
      status: 'submitted',
      remarks: 'Test Submission',
      values: [
        JobFormFieldValue(fieldId: 55, value: 'karan'),
        JobFormFieldValue(fieldId: 56, value: 'karan@yopmail.com'),
        JobFormFieldValue(fieldId: 19, value: 'In Progress'),
        JobFormFieldValue(fieldId: 20, value: 'customer@yopmail.com'),
      ],
    );

    expect(
      payload.toJson(),
      {
        'job_form_id': 6,
        'status': 'submitted',
        'remarks': 'Test Submission',
        'values': [
          {'field_id': 55, 'value': 'karan'},
          {'field_id': 56, 'value': 'karan@yopmail.com'},
          {'field_id': 19, 'value': 'In Progress'},
          {'field_id': 20, 'value': 'customer@yopmail.com'},
        ],
      },
    );
  });

  test('JobFormAssignment parses GET /jobs/{id}/ forms[] contract', () {
    final assignments = JobFormAssignment.listFromJobRaw({
      'forms': [
        {
          'job_form_id': 14,
          'project_form_id': 18,
          'name': null,
          'is_submitted': true,
          'submission_id': 41,
        },
      ],
    });

    expect(assignments, hasLength(1));
    expect(assignments.single.jobFormId, 14);
    expect(assignments.single.formId, 18);
    expect(assignments.single.submissionId, 41);
  });

  test('JobFormAssignment parses job form link rows from job.forms', () {
    final assignments = JobFormAssignment.listFromJobRaw({
      'forms': [
        {'id': 6, 'form_id': 5, 'name': 'Safety Checklist'},
        {'id': 8, 'form_id': 8, 'name': 'Site Form'},
      ],
    });

    expect(assignments, hasLength(2));
    expect(assignments.first.jobFormId, 6);
    expect(assignments.first.formId, 5);
    expect(assignments.last.jobFormId, 8);
    expect(assignments.last.formId, 8);
  });

  test('JobLinkedFormSummary resolves job_form_id when id equals form_id', () {
    final linked = JobLinkedFormSummary.tryFromMap({
      'id': 8,
      'form_id': 8,
      'name': 'Site Form',
    });

    expect(linked, isNotNull);
    expect(linked!.formId, 8);
    expect(linked.jobFormId, 8);
  });

  test('JobFormAssignment parses wrapped GET /jobs/{id}/ job detail body', () {
    final job = JobRead.tryFromMap({
      'id': 24,
      'title': 'testing2',
      'forms': [
        {
          'job_form_id': 14,
          'project_form_id': 18,
          'name': null,
          'is_submitted': true,
          'submission_id': 41,
        },
      ],
    });

    expect(job, isNotNull);
    final assignments = JobFormAssignment.listFromJobRaw(job!.raw);
    expect(assignments.single.jobFormId, 14);
    expect(assignments.single.formId, 18);
    expect(assignments.single.submissionId, 41);
  });

  test('JobLinkedFormSummary parses job_form_id + project_form_id contract', () {
    final linked = JobLinkedFormSummary.tryFromMap({
      'job_form_id': 14,
      'project_form_id': 18,
      'name': null,
      'is_submitted': true,
      'submission_id': 41,
    });

    expect(linked, isNotNull);
    expect(linked!.formId, 18);
    expect(linked.jobFormId, 14);
    expect(linked.submissionId, 41);
  });

  test('JobLinkedFormSummary resolves job_form_id from template-only row', () {
    final linked = JobLinkedFormSummary.tryFromMap({
      'id': 18,
      'name': 'Site Form',
    });

    expect(linked, isNotNull);
    expect(linked!.formId, 18);
    expect(linked.jobFormId, isNull);
  });

  test('JobFormAssignment.fromLinkedForms builds links from submitted-forms', () {
    final assignments = JobFormAssignment.fromLinkedForms([
      const JobLinkedFormSummary(formId: 18, name: 'Site Form', jobFormId: 14),
      const JobLinkedFormSummary(formId: 5, name: 'Safety', jobFormId: 5),
    ]);

    expect(assignments, hasLength(2));
    expect(assignments.first.jobFormId, 14);
    expect(assignments.first.formId, 18);
  });

  test('JobFormAssignment.mergeByFormId prefers overlay job_form_id', () {
    const base = JobFormAssignment(jobFormId: 0, formId: 18);
    const overlay = JobFormAssignment(jobFormId: 14, formId: 18, submissionId: 41);

    final merged = JobFormAssignment.mergeByFormId([base], [overlay]);

    expect(merged.single.jobFormId, 14);
    expect(merged.single.submissionId, 41);
  });

  test('submit-form URL uses operative job id', () {
    expect(AppApiUrls.jobSubmitForm(18), '/api/v1/jobs/18/submit-form/');
  });
}
