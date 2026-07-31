import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/employee_role/forms/data/signature_form_value.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/features/dashboard/data/job_models.dart';

void main() {
  test('JobFormSubmitPayload sends job_pin_id for pin submit-form', () {
    const payload = JobFormSubmitPayload(
      jobPinId: 101,
      status: 'submitted',
      values: [
        JobFormFieldValue(fieldId: 170, value: 'Admin'),
        JobFormFieldValue(fieldId: 171, value: 'Something some description'),
        JobFormFieldValue(fieldId: 172, value: 'test@mailinator.com'),
      ],
    );

    expect(
      payload.toFormBody(),
      {
        'job_pin_id': 101,
        'status': 'submitted',
        'values': jsonEncode([
          {'field_id': 170, 'value': 'Admin'},
          {'field_id': 171, 'value': 'Something some description'},
          {'field_id': 172, 'value': 'test@mailinator.com'},
        ]),
      },
    );
    expect(payload.toFormBody().containsKey('job_form_id'), isFalse);
  });

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
      payload.toFormBody(),
      {
        'job_form_id': 6,
        'status': 'submitted',
        'remarks': 'Test Submission',
        'values': jsonEncode([
          {'field_id': 55, 'value': 'karan'},
          {'field_id': 56, 'value': 'karan@yopmail.com'},
          {'field_id': 19, 'value': 'In Progress'},
          {'field_id': 20, 'value': 'customer@yopmail.com'},
        ]),
      },
    );
  });

  test('JobFormSubmitPayload encodes empty values as JSON array string', () {
    const payload = JobFormSubmitPayload(
      jobFormId: 14,
      status: 'submitted',
      values: [],
    );

    expect(payload.toFormBody()['values'], '[]');
  });

  test('prepareJobFormValuesForApi clamps answers to varchar(100)', () {
    final values = prepareJobFormValuesForApi([
      JobFormFieldValue(fieldId: 1, value: 'x' * 120),
      JobFormFieldValue(
        fieldId: 2,
        value: jsonEncode({
          'name': 'photo.jpg',
          'path': '/data/user/0/${'x' * 200}/photo.jpg',
        }),
      ),
    ]);

    expect(values, hasLength(2));
    expect(values.first.value.length, kJobFormApiValueMaxLength);
    expect(values.last.value, 'photo.jpg');
  });

  test('prepareJobFormValuesForApi keeps attachment rows with local file path', () {
    final values = prepareJobFormValuesForApi([
      const JobFormFieldValue(
        fieldId: 41,
        value: '',
        fieldType: 'image_upload',
        localFilePath: '/data/user/0/app/files/f41_photo.jpg',
      ),
    ]);

    expect(values, hasLength(1));
    expect(values.single.value, 'f41_photo.jpg');
    expect(values.single.localFilePath, '/data/user/0/app/files/f41_photo.jpg');
  });

  test('splitJobFormValuesForSubmit matches website scalar vs file split', () {
    final values = [
      const JobFormFieldValue(
        fieldId: 41,
        value: 'photo.jpg',
        fieldType: 'image_upload',
        localFilePath: '/tmp/photo.jpg',
      ),
      const JobFormFieldValue(fieldId: 42, value: 'anirudh'),
      const JobFormFieldValue(fieldId: 43, value: 'testing'),
      const JobFormFieldValue(
        fieldId: 46,
        value: 'sig_f46.png',
        fieldType: 'signature',
        localFilePath: '/tmp/sig_f46.png',
      ),
      const JobFormFieldValue(fieldId: 47, value: 'IN'),
    ];

    final split = splitJobFormValuesForSubmit(values);

    expect(split.scalars.map((v) => v.fieldId), [42, 43, 47]);
    expect(split.attachments.map((v) => v.fieldId), [41, 46]);
  });

  test('buildJobFormSubmitRequestParts sends job_pin_id for level pin forms', () {
    final parts = buildJobFormSubmitRequestParts(
      jobPinId: 14,
      status: 'submitted',
      values: const [
        JobFormFieldValue(fieldId: 1, value: 'answer'),
      ],
    );

    expect(parts.formFields['job_pin_id'], 14);
    expect(parts.formFields.containsKey('job_form_id'), isFalse);
  });

  test('buildJobFormSubmitRequestParts excludes files from values JSON', () {
    final parts = buildJobFormSubmitRequestParts(
      jobFormId: 73,
      status: 'submitted',
      values: [
        const JobFormFieldValue(
          fieldId: 41,
          value: 'photo.jpg',
          fieldType: 'image_upload',
          localFilePath: '/tmp/photo.jpg',
        ),
        const JobFormFieldValue(fieldId: 42, value: 'anirudh'),
        const JobFormFieldValue(
          fieldId: 46,
          value: 'sig_f46.png',
          fieldType: 'signature',
          localFilePath: '/tmp/sig_f46.png',
        ),
      ],
    );

    expect(parts.formFields['job_form_id'], 73);
    expect(parts.formFields['status'], 'submitted');
    expect(
      parts.formFields['values'],
      jsonEncode([
        {'field_id': 42, 'value': 'anirudh'},
      ]),
    );
    expect(parts.scalarValues, hasLength(1));
    expect(parts.attachments, hasLength(2));
  });

  test('prepareJobFormValuesForApi maps PNG base64 to short signature filename', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final signature = await encodeSignaturePngForApi([
      [const Offset(12.5, 48), const Offset(140, 52.5), const Offset(210, 44)],
    ]);
    expect(signature, isNotNull);

    final values = prepareJobFormValuesForApi([
      JobFormFieldValue(fieldId: 46, value: signature!),
    ]);

    expect(values.single.value, 'sig_f46.png');
    expect(values.single.value.length, lessThanOrEqualTo(kJobFormApiValueMaxLength));
    expect(isSignatureApiPayload(values.single.value), isTrue);
  });

  test('isSignatureApiPayload rejects inline PNG base64', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final signature = await encodeSignaturePngForApi([
      [const Offset(1, 2), const Offset(3, 4), const Offset(20, 10)],
    ]);
    expect(signature, isNotNull);
    expect(isSignatureApiPayload(signature!), isFalse);
    expect(isSignatureApiPayload('sig_f46.png'), isTrue);
  });

  test('clampJobFormFieldValueForApi keeps datetime timestamp as yyyy-MM-ddTHH:mm', () {
    expect(
      clampJobFormFieldValueForApi(
        '2026-06-25T18:38:00.000',
        fieldId: 76,
        fieldType: 'datetime',
      ),
      '2026-06-25T18:38',
    );
    expect(
      normalizeJobFormDateTimeValue('2026-06-25T18:38'),
      '2026-06-25T18:38',
    );
    expect(
      JobFormFieldValue.fromJson({
        'field_id': 76,
        'field_type': 'datetime',
        'value': '2026-06-25T18:38:00.000',
      }).value,
      '2026-06-25T18:38',
    );
  });

  test('clampJobFormFieldValueForApi strips ISO timestamp to yyyy-MM-dd', () {
    expect(
      clampJobFormFieldValueForApi(
        '2026-06-25T00:00:00.000',
        fieldId: 90,
        fieldType: 'date',
      ),
      '2026-06-25',
    );
    expect(
      prepareJobFormValuesForApi([
        const JobFormFieldValue(
          fieldId: 90,
          value: '2026-06-25T00:00:00.000',
          fieldType: 'date',
        ),
      ]).single.value,
      '2026-06-25',
    );
    expect(
      JobFormFieldValue.fromJson({
        'field_id': 90,
        'field_type': 'date',
        'value': '2026-06-25T00:00:00.000',
      }).value,
      '2026-06-25',
    );
    expect(
      normalizeJobFormDateValue('20260625'),
      '2026-06-25',
    );
  });

  test('prepareJobFormRemarksForApi clamps remarks to varchar(100)', () {
    expect(
      prepareJobFormRemarksForApi('a' * 150)?.length,
      kJobFormApiValueMaxLength,
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

  test('JobLinkedFormSummary.listFromJobRaw parses GET /jobs/{id}/ forms[]', () {
    final forms = JobLinkedFormSummary.listFromJobRaw({
      'forms': [
        {
          'job_form_id': 14,
          'project_form_id': 18,
          'name': 'Site Form',
          'is_submitted': false,
        },
        {'id': 6, 'form_id': 5, 'name': 'Safety Checklist'},
      ],
    });

    expect(forms, hasLength(2));
    expect(forms.first.formId, 18);
    expect(forms.first.jobFormId, 14);
    expect(forms.first.name, 'Site Form');
    expect(forms.last.formId, 5);
    expect(forms.last.jobFormId, 6);
    expect(forms.last.name, 'Safety Checklist');
  });

  test('JobLinkedFormSummary parses service job dynamic_form_id + is_submitted', () {
    final forms = JobLinkedFormSummary.listFromJobRaw({
      'forms': [
        {
          'job_form_id': 50,
          'dynamic_form_id': 34,
          'name': 'Project 2',
          'is_submitted': false,
          'submission_id': null,
        },
        {
          'job_form_id': 51,
          'dynamic_form_id': 72,
          'name': 'water pump',
          'is_submitted': true,
          'submission_id': 9,
        },
      ],
    });

    expect(forms, hasLength(2));
    expect(forms.first.formId, 34);
    expect(forms.first.jobFormId, 50);
    expect(forms.first.isSubmitted, isFalse);
    expect(forms.last.formId, 72);
    expect(forms.last.isSubmitted, isTrue);
    expect(forms.last.submissionId, 9);
  });

  test('JobLinkedFormSummary.listFromJobRaw returns empty when forms missing', () {
    expect(JobLinkedFormSummary.listFromJobRaw({'id': 35}), isEmpty);
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
