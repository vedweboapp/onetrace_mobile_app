import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';

/// Job completion requires every pin's **server status** to be Complete.
///
/// Local form saves / session keys are not enough — even a single pin must
/// have Complete status before the job can be finished.
bool isPinReadyForJobCompletion(EmployeeJobDrawingPin pin) {
  return pin.isStatusComplete;
}

int countIncompleteAssignedPins(List<EmployeeJobDrawingLevel> levels) {
  return collectJobPinEntries(levels)
      .where((entry) => !isPinReadyForJobCompletion(entry.pin))
      .length;
}

/// Pins whose form/QR work is done in-app but server status is not Complete yet.
List<EmployeeJobDrawingPin> pinsReadyToMarkCompleteStatus({
  required List<EmployeeJobDrawingLevel> levels,
  Set<String> completedPinFormKeys = const {},
  Set<String> scannedPinQrKeys = const {},
  Set<String> locallySubmittedPinFormKeys = const {},
  bool Function(EmployeeJobDrawingPin pin) requiresQr = _defaultRequiresQr,
}) {
  return collectJobPinEntries(levels)
      .map((entry) => entry.pin)
      .where((pin) {
        if (pin.isStatusComplete) return false;
        final formOk = !pin.hasForm ||
            pin.isFormSubmitted ||
            completedPinFormKeys.contains(pin.formKey) ||
            locallySubmittedPinFormKeys.contains(pin.formKey);
        if (!formOk) return false;
        if (!requiresQr(pin)) return true;
        return pin.hasQrCode || scannedPinQrKeys.contains(pin.formKey);
      })
      .toList(growable: false);
}

bool _defaultRequiresQr(EmployeeJobDrawingPin pin) => pin.qrCodeFieldPresent;

Set<String> pinFormKeysFromLocalSubmissions({
  required List<EmployeeJobDrawingLevel> levels,
  required List<CachedJobFormSubmission> rows,
}) {
  final entries = collectJobPinEntries(levels);
  final pinsWithForms =
      entries.map((entry) => entry.pin).where((pin) => pin.hasForm).toList();
  final keys = <String>{};
  for (final entry in entries) {
    if (pinHasLocalSubmittedForm(
      entry.pin,
      rows,
      pinsWithForms: pinsWithForms,
    )) {
      keys.add(entry.pin.formKey);
    }
  }
  return keys;
}

bool pinHasLocalSubmittedForm(
  EmployeeJobDrawingPin pin,
  List<CachedJobFormSubmission> rows, {
  List<EmployeeJobDrawingPin> pinsWithForms = const [],
}) {
  if (!pin.hasForm) return false;
  final formId = pin.projectFormId;
  if (formId == null || formId <= 0) return false;

  final pinLinkIds = <int>{
    pin.id,
    if (pin.jobPinId != null && pin.jobPinId! > 0) pin.jobPinId!,
    if (pin.resolvedJobFormId != null && pin.resolvedJobFormId! > 0)
      pin.resolvedJobFormId!,
  };

  for (final row in rows) {
    if (!row.isSubmitted || row.formId != formId) continue;

    final jobPinId = row.jobPinId;
    if (jobPinId != null && jobPinId > 0 && pinLinkIds.contains(jobPinId)) {
      return true;
    }
  }

  final owners = pinsWithForms
      .where((candidate) => candidate.projectFormId == formId)
      .toList(growable: false);
  if (owners.length == 1 && owners.single.id == pin.id) {
    return rows.any((row) => row.isSubmitted && row.formId == formId);
  }

  return false;
}
