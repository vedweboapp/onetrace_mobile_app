import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/application/operative_last_working_pin.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';

EmployeeJobDrawingPin _pin({
  required int id,
  bool complete = false,
  bool hasForm = true,
}) {
  return EmployeeJobDrawingPin(
    id: id,
    name: 'Pin $id',
    description: '',
    location: '$id',
    xCoordinate: 0,
    yCoordinate: 0,
    statusName: complete ? 'Complete' : 'Pending',
    statusBackground: const Color(0xFF000000),
    statusForeground: const Color(0xFFFFFFFF),
    itemName: 'Item',
    attachmentCount: 0,
    projectFormId: hasForm ? 10 : null,
    projectFormSubmissionId: complete && hasForm ? 1 : null,
  );
}

EmployeeJobDrawingLevel _level(List<EmployeeJobDrawingPin> pins) {
  return EmployeeJobDrawingLevel(
    id: 7,
    name: 'Level 1',
    order: 0,
    drawingFileUrl: 'https://example.com/a.pdf',
    plots: [
      EmployeeJobDrawingPlot(
        id: 1,
        name: 'Plot 1',
        borderColor: const Color(0xFF0000FF),
        backgroundColor: const Color(0x110000FF),
        pins: pins,
      ),
    ],
  );
}

void main() {
  test('prefers last incomplete working pin', () {
    final level = _level([
      _pin(id: 1, complete: true),
      _pin(id: 2),
      _pin(id: 3),
    ]);
    final id = resolveOperativeFocusPinId(
      level: level,
      state: const EmployeeJobDetailState(),
      lastWorkingPinId: 2,
    );
    expect(id, 2);
  });

  test('skips completed last pin and returns first incomplete', () {
    final level = _level([
      _pin(id: 1, complete: true),
      _pin(id: 2, complete: true),
      _pin(id: 3),
    ]);
    final id = resolveOperativeFocusPinId(
      level: level,
      state: const EmployeeJobDetailState(),
      lastWorkingPinId: 2,
    );
    expect(id, 3);
  });

  test('falls back to first pin when all complete', () {
    final level = _level([
      _pin(id: 1, complete: true),
      _pin(id: 2, complete: true),
    ]);
    final id = resolveOperativeFocusPinId(
      level: level,
      state: const EmployeeJobDetailState(),
      lastWorkingPinId: null,
    );
    expect(id, 1);
  });
}
