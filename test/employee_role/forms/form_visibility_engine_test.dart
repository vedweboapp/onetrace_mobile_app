import 'package:flutter_test/flutter_test.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';
import 'package:red5/employee_role/forms/data/form_visibility_engine.dart';

void main() {
  group('FormVisibilityEngine', () {
    late List<FormMetadataSection> sections;

    setUp(() {
      sections = [
        FormMetadataSection(
          id: 50,
          sid: 'section-survey',
          name: 'Surveys Section',
          sequence: 1,
          columnCount: 2,
          isActive: true,
          fields: [
            FormMetadataField(
              id: 256,
              fid: '256',
              label: 'Door No',
              apiName: 'door_no',
              fieldType: 'single_line',
              sequence: 1,
            ),
            FormMetadataField(
              id: 257,
              fid: '257',
              label: 'Access',
              apiName: 'access',
              fieldType: 'picklist',
              sequence: 2,
              options: const ['Gained', 'Not Gained'],
              isRequired: true,
            ),
            FormMetadataField(
              id: 429,
              fid: '1787144732687',
              label: 'Flat Number',
              apiName: 'flat_number',
              fieldType: 'single_line',
              sequence: 3,
            ),
            FormMetadataField(
              id: 433,
              fid: '1787144806390',
              label: 'Door Color',
              apiName: 'door_color',
              fieldType: 'picklist',
              sequence: 4,
              options: const ['Light', 'Dark'],
            ),
          ],
        ),
        FormMetadataSection(
          id: 51,
          sid: 'section-1787140785310',
          name: 'Section 1: Door Identification',
          sequence: 2,
          columnCount: 2,
          isActive: true,
          fields: [
            FormMetadataField(
              id: 261,
              fid: '1787140805277',
              label: 'Door Reference/Location',
              apiName: 'door_reference/location',
              fieldType: 'single_line',
              sequence: 1,
            ),
          ],
        ),
      ];
    });

    List<Map<String, dynamic>> doorSurveyAccessRule() {
      return [
        {
          'logic': {
            'blocks': [
              {
                'api_name': 'access',
                'field_id': 257,
                'condition': 'is',
                'value': 'Gained',
                'output_fields': [
                  {
                    'action': 'show',
                    'target_type': 'section',
                    'field_api_name': '__section__:51',
                  },
                  {
                    'action': 'show',
                    'target_type': 'field',
                    'field_api_name': '__field__:433',
                  },
                ],
                'else_blocks': [
                  {
                    'else_value': 'Not Gained',
                    'else_condition': 'is',
                    'else_output_fields': [
                      {
                        'action': 'show',
                        'target_type': 'field',
                        'field_api_name': '__field__:429',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        },
      ];
    }

    test('hides rule-controlled sections and fields until access is chosen', () {
      final engine = FormVisibilityEngine(
        sections: sections,
        rules: doorSurveyAccessRule(),
      );

      final initial = engine.evaluate(const {});
      expect(initial.isSectionVisible(sections[1]), isFalse);
      expect(initial.isFieldVisible(sections[0].fields[2]), isFalse);
      expect(initial.isFieldVisible(sections[0].fields[3]), isFalse);
      expect(initial.isFieldVisible(sections[0].fields[0]), isTrue);
      expect(initial.isFieldVisible(sections[0].fields[1]), isTrue);
    });

    test('shows survey follow-up sections when access is Gained', () {
      final engine = FormVisibilityEngine(
        sections: sections,
        rules: doorSurveyAccessRule(),
      );

      final gained = engine.evaluate({'api:access': 'Gained'});
      expect(gained.isSectionVisible(sections[1]), isTrue);
      expect(gained.isFieldVisible(sections[0].fields[3]), isTrue);
      expect(gained.isFieldVisible(sections[0].fields[2]), isFalse);
    });

    test('shows not-entry fields when access is Not Gained', () {
      final engine = FormVisibilityEngine(
        sections: sections,
        rules: doorSurveyAccessRule(),
      );

      final notGained = engine.evaluate({'api:access': 'Not Gained'});
      expect(notGained.isSectionVisible(sections[1]), isFalse);
      expect(notGained.isFieldVisible(sections[0].fields[2]), isTrue);
      expect(notGained.isFieldVisible(sections[0].fields[3]), isFalse);
    });

    test('nested block shows child field when parent answer is Yes', () {
      final hingeSection = FormMetadataSection(
        id: 58,
        sid: 'section-hinges',
        name: 'Section 5: Hinges',
        sequence: 6,
        columnCount: 2,
        isActive: true,
        fields: [
          FormMetadataField(
            id: 272,
            fid: '1787141079156',
            label: 'Does the door leaf have a lipping',
            apiName: 'does_the_door_leaf_have_a_lipping',
            fieldType: 'radio',
            sequence: 2,
            options: const ['Yes', 'No'],
          ),
          FormMetadataField(
            id: 273,
            fid: '1787141092475',
            label: 'Lipping Thickness (mm)',
            apiName: 'lipping_thickness_(mm)',
            fieldType: 'single_line',
            sequence: 3,
          ),
        ],
      );

      final engine = FormVisibilityEngine(
        sections: [...sections, hingeSection],
        rules: [
          {
            'logic': {
              'blocks': [
                {
                  'api_name': 'does_the_door_leaf_have_a_lipping',
                  'field_id': '1787141079156',
                  'condition': 'is',
                  'value': 'Yes',
                  'output_fields': [
                    {
                      // Template UID must NOT win over `__field__:273`.
                      'field_id': '1787141092475',
                      'f_id': '1787141092475',
                      'field_uid': '1787141092475',
                      'api_name': 'lipping_thickness_(mm)',
                      'action': 'show',
                      'target_type': 'field',
                      'field_api_name': '__field__:273',
                    },
                  ],
                },
              ],
            },
          },
        ],
      );

      final hidden = engine.evaluate(const {});
      expect(hidden.isFieldVisible(hingeSection.fields[1]), isFalse);

      final shown = engine.evaluate({
        'api:does_the_door_leaf_have_a_lipping': 'Yes',
      });
      expect(shown.isFieldVisible(hingeSection.fields[1]), isTrue);
    });

    test('resolves show targets via api_name when field_id is a template uid', () {
      final section = FormMetadataSection(
        id: 52,
        name: 'Section 2: Door Leaf',
        sequence: 3,
        columnCount: 2,
        isActive: true,
        fields: [
          FormMetadataField(
            id: 274,
            label: 'Glue holding?',
            apiName: 'is_the_glue_still_holding_these_products_firmly_in_place?',
            fieldType: 'radio',
            sequence: 4,
            options: const ['Yes', 'No'],
          ),
          FormMetadataField(
            id: 275,
            label: 'Actions section 2',
            apiName: 'actions_section_2',
            fieldType: 'multi_select',
            sequence: 5,
            options: const ['Door Lipping Replacement'],
          ),
        ],
      );

      final engine = FormVisibilityEngine(
        sections: [section],
        rules: [
          {
            'logic': {
              'blocks': [
                {
                  'api_name':
                      'is_the_glue_still_holding_these_products_firmly_in_place?',
                  'field_id': '1787141102972',
                  'condition': 'is',
                  'value': 'No',
                  'field_api_name': '__field__:274',
                  'output_fields': [
                    {
                      'f_id': '1787141143555',
                      'field_id': '1787141143555',
                      'api_name': 'actions_section_2',
                      'action': 'show',
                      'target_type': 'field',
                      'field_api_name': '__field__:275',
                    },
                  ],
                  'else_blocks': [],
                },
              ],
            },
          },
        ],
      );

      expect(
        engine.evaluate(const {}).isFieldVisible(section.fields[1]),
        isFalse,
      );
      expect(
        engine
            .evaluate({
              'api:is_the_glue_still_holding_these_products_firmly_in_place?':
                  'No',
            })
            .isFieldVisible(section.fields[1]),
        isTrue,
      );
    });
  });
}
