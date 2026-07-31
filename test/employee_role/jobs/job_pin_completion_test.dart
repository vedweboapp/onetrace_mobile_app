import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';
import 'package:red5/employee_role/jobs/data/job_pin_completion.dart';

EmployeeJobDrawingPin _pin({
  required int id,
  int? jobPinId,
  int? projectFormId,
  int? submissionId,
  String statusName = 'In Progress',
}) {
  return EmployeeJobDrawingPin(
    id: id,
    name: 'Pin $id',
    description: '',
    location: '',
    xCoordinate: 0,
    yCoordinate: 0,
    statusName: statusName,
    statusBackground: const Color(0xFFFFFFFF),
    statusForeground: const Color(0xFF000000),
    itemName: '',
    attachmentCount: 0,
    jobPinId: jobPinId ?? id,
    projectFormId: projectFormId,
    projectFormSubmissionId: submissionId,
  );
}

List<EmployeeJobDrawingLevel> _levelsWithPin(EmployeeJobDrawingPin pin) {
  return [
    EmployeeJobDrawingLevel(
      id: 1,
      name: 'Level 1',
      order: 1,
      drawingFileUrl: null,
      plots: [
        EmployeeJobDrawingPlot(
          id: 1,
          name: 'Plot 1',
          borderColor: const Color(0xFF000000),
          backgroundColor: const Color(0xFFFFFFFF),
          pins: [pin],
        ),
      ],
    ),
  ];
}

void main() {
  test('job completion requires Complete pin status even when form submitted', () {
    final pin = _pin(id: 1, projectFormId: 18, submissionId: 42);

    expect(pin.isFormSubmitted, isTrue);
    expect(pin.isStatusComplete, isFalse);
    expect(isPinReadyForJobCompletion(pin), isFalse);
    expect(countIncompleteAssignedPins(_levelsWithPin(pin)), 1);
  });

  test('job completion allows pin with Complete status', () {
    final pin = _pin(
      id: 1,
      projectFormId: 18,
      statusName: 'Complete',
    );

    expect(isPinReadyForJobCompletion(pin), isTrue);
    expect(countIncompleteAssignedPins(_levelsWithPin(pin)), 0);
  });

  test('single pin still blocks job when status is not Complete', () {
    final levels = _levelsWithPin(_pin(id: 5, jobPinId: 101, projectFormId: 18));
    expect(countIncompleteAssignedPins(levels), 1);
  });

  test('pinsReadyToMarkCompleteStatus finds form-done pins without Complete status', () {
    final pin = _pin(id: 5, jobPinId: 101, projectFormId: 18);
    final levels = _levelsWithPin(pin);
    final ready = pinsReadyToMarkCompleteStatus(
      levels: levels,
      completedPinFormKeys: {'5_18'},
      scannedPinQrKeys: {'5_18'},
    );

    expect(ready, hasLength(1));
    expect(ready.single.id, 5);
  });

  test('pinHasLocalSubmittedForm accepts single-pin job without job_pin_id match', () {
    final pin = _pin(id: 5, jobPinId: 101, projectFormId: 18);
    final rows = [
      CachedJobFormSubmission(
        localId: 'local-1',
        jobId: 24,
        formId: 18,
        jobFormId: 0,
        status: 'submitted',
        values: const [
          JobFormFieldValue(fieldId: 1, value: 'answer'),
        ],
        syncStatus: JobFormSubmissionSyncStatus.synced,
        updatedAt: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    ];

    expect(
      pinHasLocalSubmittedForm(
        pin,
        rows,
        pinsWithForms: [pin],
      ),
      isTrue,
    );
  });
}
