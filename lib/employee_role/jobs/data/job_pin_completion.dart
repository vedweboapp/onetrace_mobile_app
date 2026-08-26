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

/// Whether QR must be scanned before this pin can be marked Complete.
///
/// Formless pins often include an empty `qr_code` key from the API. That must
/// not block Complete Job when there is no form to collect the scan in.
bool pinRequiresQrForCompletion(EmployeeJobDrawingPin pin) {
  if (!pin.hasForm) return false;
  return pin.qrCodeFieldPresent;
}

/// Pins whose form/QR work is done in-app but server status is not Complete yet.
List<EmployeeJobDrawingPin> pinsReadyToMarkCompleteStatus({
  required List<EmployeeJobDrawingLevel> levels,
  Set<String> completedPinFormKeys = const {},
  Set<String> scannedPinQrKeys = const {},
  Set<String> locallySubmittedPinFormKeys = const {},
  bool Function(EmployeeJobDrawingPin pin) requiresQr =
      pinRequiresQrForCompletion,
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

/// True when the job payload includes drawing levels.
bool jobHasDrawingLevels(List<EmployeeJobDrawingLevel> levels) {
  return levels.isNotEmpty;
}

/// Pin id for `PATCH /jobs/{id}/` status updates.
///
/// - Job has levels → level pin `id`
/// - Job has no levels → `job_pin_id`
int? pinStatusUpdateId(
  EmployeeJobDrawingPin pin, {
  required bool jobHasLevels,
}) {
  if (jobHasLevels) {
    if (pin.id > 0) return pin.id;
    if (pin.jobPinId != null && pin.jobPinId! > 0) return pin.jobPinId;
    return null;
  }
  if (pin.jobPinId != null && pin.jobPinId! > 0) return pin.jobPinId;
  if (pin.id > 0) return pin.id;
  return null;
}

/// Opposite id for a single retry after a "not linked" API error.
int? pinStatusAlternateId(
  EmployeeJobDrawingPin pin,
  int primary, {
  required bool jobHasLevels,
}) {
  if (jobHasLevels) {
    if (pin.jobPinId != null &&
        pin.jobPinId! > 0 &&
        pin.jobPinId != primary) {
      return pin.jobPinId;
    }
    return null;
  }
  if (pin.id > 0 && pin.id != primary) return pin.id;
  return null;
}
