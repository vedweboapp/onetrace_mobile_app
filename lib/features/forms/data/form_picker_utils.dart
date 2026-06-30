import 'package:red5/core/models/named_id_option.dart';
import 'package:red5/features/forms/data/form_models.dart';

extension FormSummaryPickerX on FormSummary {
  NamedIdOption get toPickerOption => NamedIdOption(id: id, name: name);
}

extension FormSummaryListPickerX on List<FormSummary> {
  List<NamedIdOption> toActivePickerOptions() => where((form) => form.isActive)
      .map((form) => form.toPickerOption)
      .toList(growable: false);

  /// Keeps [project_form] rows whose installation type id equals the pin item's
  /// installation type id. Returns nothing when the pin has no installation type.
  List<FormSummary> matchingInstallationType(int? pinInstallationTypeId) {
    if (pinInstallationTypeId == null) return const [];
    return where(
      (form) => form.installationTypeId == pinInstallationTypeId,
    ).toList(growable: false);
  }
}
