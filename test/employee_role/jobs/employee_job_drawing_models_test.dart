import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';

void main() {
  group('parseEmployeeJobDrawingLevels', () {
    test('parses pins with project_form and job_pin_id when forms array is empty',
        () {
      final levels = parseEmployeeJobDrawingLevels([
        {
          'id': 26,
          'name': 'Verse',
          'order': 1,
          'plots': [
            {
              'id': 73,
              'name': 'Plot 1',
              'plot_border': '#059669',
              'plot_bg': '#0596690D',
              'pins': [
                {
                  'id': 364,
                  'job_pin_id': 14,
                  'location': '1',
                  'x_coordinate': 19.97,
                  'y_coordinate': 21.0,
                  'project_form': {
                    'id': 42,
                    'name': 'SPY - Form',
                    'submission_id': null,
                    'submission_status': null,
                  },
                  'qr_code': null,
                  'item_detail': {'name': 'Nylon Composite'},
                  'status_detail': {
                    'status_name': 'To Do',
                    'bg_colour': '#808811',
                    'text_colour': '#e9edf7',
                  },
                },
                {
                  'id': 367,
                  'job_pin_id': 15,
                  'location': '4',
                  'x_coordinate': 43.07,
                  'y_coordinate': 49.78,
                  'project_form': {
                    'id': 42,
                    'name': 'SPY - Form',
                    'submission_id': 99,
                    'submission_status': 'submitted',
                  },
                  'qr_code': 'QR-123',
                  'item_detail': {'name': 'Nylon Composite'},
                  'status_detail': {
                    'status_name': 'To Do',
                    'bg_colour': '#808811',
                    'text_colour': '#e9edf7',
                  },
                },
              ],
            },
          ],
        },
      ]);

      expect(levels, hasLength(1));
      expect(levels.first.plots, hasLength(1));
      expect(levels.first.plots.first.pins, hasLength(2));

      final firstPin = levels.first.plots.first.pins.first;
      expect(firstPin.displayLabel, 'Pin 1');
      expect(firstPin.projectFormId, 42);
      expect(firstPin.projectFormName, 'SPY - Form');
      expect(firstPin.jobPinId, 14);
      expect(firstPin.resolvedJobFormId, 14);
      expect(firstPin.isFormSubmitted, isFalse);
      expect(firstPin.hasQrCode, isFalse);
      expect(firstPin.qrCodeFieldPresent, isTrue);

      final secondPin = levels.first.plots.first.pins[1];
      expect(secondPin.displayLabel, 'Pin 4');
      expect(secondPin.jobPinId, 15);
      expect(secondPin.isFormSubmitted, isTrue);
      expect(secondPin.hasQrCode, isTrue);
      expect(secondPin.qrCodeFieldPresent, isTrue);

      final tasks = collectPinFormTasks(levels);
      expect(tasks, hasLength(2));
      expect(tasks.map((task) => task.jobPinId).toList(), [14, 15]);
      expect(tasks[1].submissionId, 99);

      final entries = collectJobPinEntries(levels);
      expect(entries, hasLength(2));
      expect(entries.first.plotName, 'Plot 1');
      expect(entries.first.levelName, 'Verse');
    });

    test('empty qr_code string still marks field present without scanned value', () {
      final levels = parseEmployeeJobDrawingLevels([
        {
          'id': 1,
          'name': 'L1',
          'order': 1,
          'plots': [
            {
              'id': 1,
              'name': 'P1',
              'pins': [
                {
                  'id': 10,
                  'job_pin_id': 1,
                  'x_coordinate': 1,
                  'y_coordinate': 2,
                  'qr_code': '',
                  'project_form': {'id': 5, 'name': 'Form'},
                },
              ],
            },
          ],
        },
      ]);

      final pin = levels.first.plots.first.pins.single;
      expect(pin.qrCodeFieldPresent, isTrue);
      expect(pin.hasQrCode, isFalse);
    });

    test('parses pin and item_detail attachments for open-attachment flow', () {
      final levels = parseEmployeeJobDrawingLevels([
        {
          'id': 1,
          'name': 'L1',
          'order': 1,
          'plots': [
            {
              'id': 1,
              'name': 'P1',
              'pins': [
                {
                  'id': 10,
                  'job_pin_id': 1,
                  'x_coordinate': 1,
                  'y_coordinate': 2,
                  'attachments': [],
                  'item_detail': {
                    'name': 'Full tip',
                    'attachments': [
                      {
                        'id': 27,
                        'file':
                            'http://example.com/media/attachments/guide.png',
                        'file_name': 'guide.png',
                        'content_type_value': 'image/png',
                      },
                    ],
                  },
                  'project_form': {'id': 5, 'name': 'Form'},
                },
              ],
            },
          ],
        },
      ]);

      final pin = levels.first.plots.first.pins.single;
      expect(pin.hasAttachments, isTrue);
      expect(pin.attachments, hasLength(1));
      expect(pin.attachments.single.name, 'guide.png');
      expect(pin.attachments.single.url, contains('/media/attachments/guide.png'));
      expect(pin.attachmentCount, 1);
    });
  });
}
