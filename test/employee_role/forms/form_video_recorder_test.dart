import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/forms/data/form_video_recorder_constraints.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';

void main() {
  test('isVideoRecorderFieldType recognizes API field types', () {
    expect(isVideoRecorderFieldType('video_recorder'), isTrue);
    expect(isVideoRecorderFieldType('video_recording'), isTrue);
    expect(isVideoRecorderFieldType('image_upload'), isFalse);
  });

  test('FormVideoRecorderConstraints enforces duration and size limits', () {
    expect(
      FormVideoRecorderConstraints.validate(
        duration: const Duration(seconds: 30),
        bytes: 5 * 1024 * 1024,
      ),
      isNull,
    );
    expect(
      FormVideoRecorderConstraints.validate(
        duration: const Duration(seconds: 90),
        bytes: 1024,
      ),
      isNotNull,
    );
  });

  test('isJobFormAttachmentFieldType treats video fields as attachments', () {
    expect(isJobFormAttachmentFieldType('video_recorder'), isTrue);
    expect(isJobFormAttachmentFieldType('video_upload'), isTrue);
    expect(isJobFormAttachmentFieldType('single_line'), isFalse);
  });
}
