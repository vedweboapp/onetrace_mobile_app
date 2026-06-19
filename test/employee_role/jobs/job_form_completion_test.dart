import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';

void main() {
  test('allRequiredFormsComplete is false when a linked form is missing', () {
    const state = EmployeeJobDetailState(
      formIds: [18, 20],
      completedFormIds: {18},
    );

    expect(state.allRequiredFormsComplete, isFalse);
  });

  test('allRequiredFormsComplete is true only when every linked form is done', () {
    const state = EmployeeJobDetailState(
      formIds: [18, 20],
      completedFormIds: {18, 20},
    );

    expect(state.allRequiredFormsComplete, isTrue);
  });

  test('allRequiredFormsComplete is false when job has no linked forms', () {
    const state = EmployeeJobDetailState(formIds: []);

    expect(state.allRequiredFormsComplete, isFalse);
  });
}
