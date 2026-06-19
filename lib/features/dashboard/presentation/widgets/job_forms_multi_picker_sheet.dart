import 'package:flutter/material.dart';
import 'package:red5/core/models/named_id_option.dart';
import 'package:red5/features/dashboard/presentation/widgets/forms_multi_picker_sheet.dart';

@Deprecated('Use showFormsMultiPickerSheet from forms_multi_picker_sheet.dart')
Future<List<NamedIdOption>?> showJobFormsMultiPickerSheet({
  required BuildContext context,
  required List<NamedIdOption> forms,
  required List<NamedIdOption> selected,
  String description = 'Choose one or more forms to attach to this job.',
}) {
  return showFormsMultiPickerSheet(
    context: context,
    forms: forms,
    selected: selected,
    description: description,
  );
}
