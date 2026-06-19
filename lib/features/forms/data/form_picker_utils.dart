import 'package:red5/core/models/named_id_option.dart';
import 'package:red5/features/forms/data/form_models.dart';

extension FormSummaryPickerX on FormSummary {
  NamedIdOption get toPickerOption => NamedIdOption(id: id, name: name);
}

extension FormSummaryListPickerX on List<FormSummary> {
  List<NamedIdOption> toActivePickerOptions() => where((form) => form.isActive)
      .map((form) => form.toPickerOption)
      .toList(growable: false);
}
