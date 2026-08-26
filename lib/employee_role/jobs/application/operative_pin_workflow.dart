import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_qr_scan_flow.dart';
import 'package:red5/employee_role/jobs/application/operative_canvas_bridge.dart';
import 'package:red5/employee_role/jobs/application/operative_last_working_pin.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/jobs/data/job_pin_completion.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_confirmation_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_form_page.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/operative_pin_checklist_sheet.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/operative_pin_complete_sheet.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/operative_job_form_sync_result_sheet.dart';

bool operativePinShowsQr(EmployeeJobDrawingPin pin) =>
    pinRequiresQrForCompletion(pin);

/// Bumped whenever a pin popup session starts so a stale pin-1 loop cannot
/// reopen its sheet after the user moves on to pin 2.
int _operativePinWorkflowGeneration = 0;

bool isOperativePinComplete(
  EmployeeJobDrawingPin pin,
  EmployeeJobDetailState state,
) {
  if (pin.isStatusComplete) return true;

  final formOk = !pin.hasForm ||
      pin.isFormSubmitted ||
      state.completedPinFormKeys.contains(pin.formKey);

  final qrOk = !operativePinShowsQr(pin) ||
      pin.hasQrCode ||
      state.scannedPinQrKeys.contains(pin.formKey);

  return formOk && qrOk;
}

int countIncompleteOperativePins(
  EmployeeJobDetail job,
  EmployeeJobDetailState state,
) {
  return collectJobPinEntries(job.levels)
      .where((entry) => !isOperativePinComplete(entry.pin, state))
      .length;
}

Future<void> handleOperativePinTap({
  required BuildContext context,
  required ProviderContainer container,
  required int jobId,
  required int pinId,
  required bool skipChecklist,
}) async {
  final generation = ++_operativePinWorkflowGeneration;

  // Drop any previous pin popup so only the newly selected pin can show one.
  if (context.mounted) {
    Navigator.of(context).popUntil((route) => route is! ModalBottomSheetRoute);
  }

  final state = container.read(employeeJobDetailControllerProvider);
  final job = state.job;
  if (job == null) return;

  final pin = findEmployeeJobPinById(job.levels, pinId);
  if (pin == null) return;

  final levelId = pin.levelId ??
      () {
        for (final level in job.levels) {
          for (final plot in level.plots) {
            for (final candidate in plot.pins) {
              if (candidate.id == pinId) return level.id;
            }
          }
        }
        return null;
      }();
  if (levelId != null && levelId > 0) {
    await OperativeLastWorkingPin.remember(
      jobId: jobId,
      levelId: levelId,
      pinId: pinId,
    );
  }

  final session = container.read(employeeJobSessionProvider.notifier);
  final detailController =
      container.read(employeeJobDetailControllerProvider.notifier);

  if (!skipChecklist && !session.isJobStarted(jobId)) {
    final started = await showOperativePinChecklistSheet(
      context: context,
      jobId: jobId,
      items: job.safetyChecklist,
    );
    if (!context.mounted || !started) return;
    if (generation != _operativePinWorkflowGeneration) return;
    await detailController.load(jobId: jobId);
  }

  if (!context.mounted) return;
  if (generation != _operativePinWorkflowGeneration) return;

  final detailState = container.read(employeeJobDetailControllerProvider);
  final liveJob = detailState.job ?? job;
  final livePin =
      findEmployeeJobPinById(liveJob.levels, pin.id) ?? pin;
  if (livePin.hasForm) {
    final submitted = await _openPinForm(
      context: context,
      container: container,
      jobId: jobId,
      pin: livePin,
    );
    if (generation != _operativePinWorkflowGeneration) return;
    if (!context.mounted) return;
    OperativeCanvasBridge.notifyCompletionChanged(jobId);

    final afterState = container.read(employeeJobDetailControllerProvider);
    final afterJob = afterState.job;
    final afterPin =
        findEmployeeJobPinById(afterJob?.levels ?? const [], livePin.id) ??
            livePin;
    if (submitted && isOperativePinComplete(afterPin, afterState)) {
      await _showContinueOrDoneDialog(
        context: context,
        container: container,
        jobId: jobId,
        pin: afterPin,
      );
    }
    return;
  }

  if (operativePinShowsQr(livePin)) {
    final scannedQr = await runEmployeeQrScanFlow(
      context,
      container,
      jobId: jobId,
      jobPinId: livePin.jobPinId ?? livePin.resolvedJobFormId,
    );
    if (!context.mounted || scannedQr == null) return;
    if (generation != _operativePinWorkflowGeneration) return;
    detailController.markQrCodeScanned(
      pinId: livePin.id,
      formId: livePin.projectFormId,
      qrCode: scannedQr,
    );
    await detailController.load(jobId: jobId);
    OperativeCanvasBridge.notifyCompletionChanged(jobId);
    final afterState = container.read(employeeJobDetailControllerProvider);
    final afterJob = afterState.job;
    final afterPin =
        findEmployeeJobPinById(afterJob?.levels ?? const [], livePin.id) ??
            livePin;
    if (isOperativePinComplete(afterPin, afterState)) {
      await _showContinueOrDoneDialog(
        context: context,
        container: container,
        jobId: jobId,
        pin: afterPin,
      );
    }
  }
}

Future<bool> _openPinForm({
  required BuildContext context,
  required ProviderContainer container,
  required int jobId,
  required EmployeeJobDrawingPin pin,
}) async {
  final formId = pin.projectFormId;
  if (formId == null || formId <= 0) return false;

  final jobPinId = pin.jobPinId ?? pin.resolvedJobFormId;
  if (jobPinId == null || jobPinId <= 0) return false;

  // Open immediately with the pin we already have — don't block on a full
  // job refresh. The form page loads its own template/values.
  final controller =
      container.read(employeeJobDetailControllerProvider.notifier);
  final submissionId = pin.projectFormSubmissionId;

  final submitted = await context.push<bool>(
    EmployeeJobFormPage.path,
    extra: <String, Object?>{
      'formId': formId,
      'jobId': jobId,
      'jobPinId': jobPinId,
      if (submissionId != null && submissionId > 0) 'submissionId': submissionId,
      'pinId': pin.id,
      'requiresPinQr': pin.qrCodeFieldPresent,
    },
  );
  if (!context.mounted || submitted != true) return false;
  controller.markFormComplete(formId, pinId: pin.id);
  // Refresh in the background after submit — don't serialize both awaits.
  unawaited(controller.load(jobId: jobId));
  unawaited(controller.refreshCompletedForms());

  final afterState = container.read(employeeJobDetailControllerProvider);
  final afterJob = afterState.job;
  final afterPin =
      findEmployeeJobPinById(afterJob?.levels ?? const [], pin.id) ?? pin;
  if (afterJob != null &&
      isOperativePinComplete(afterPin, afterState) &&
      !afterPin.isStatusComplete) {
    try {
      await container
          .read(employeeJobRepositoryProvider)
          .markReadyPinsCompleteStatus(
            jobId: jobId,
            levels: afterJob.levels,
            completedPinFormKeys: afterState.completedPinFormKeys,
            scannedPinQrKeys: afterState.scannedPinQrKeys,
          );
      unawaited(controller.load(jobId: jobId));
    } catch (_) {
      // Job completion will retry marking pin status.
    }
  }
  return true;
}

Future<void> _showContinueOrDoneDialog({
  required BuildContext context,
  required ProviderContainer container,
  required int jobId,
  EmployeeJobDrawingPin? pin,
}) async {
  final state = container.read(employeeJobDetailControllerProvider);
  final job = state.job;
  final remainingPins = job == null
      ? 0
      : countIncompleteOperativePins(job, state);

  final choice = await showOperativePinCompleteSheet(
    context: context,
    pin: pin,
    remainingPins: remainingPins,
  );
  if (!context.mounted || choice != true) return;
  await completeOperativeJob(context: context, container: container, jobId: jobId);
}

/// Validates that pin/form work is done, syncs pending forms, then opens the
/// confirmation screen. Actual job completion happens on that screen.
Future<bool> completeOperativeJob({
  required BuildContext context,
  required ProviderContainer container,
  required int jobId,
}) async {
  final isOnline = container.read(connectivityServiceProvider).isOnline;
  final detailController =
      container.read(employeeJobDetailControllerProvider.notifier);

  if (isOnline) {
    await detailController.load(jobId: jobId);
  }
  if (!context.mounted) return false;

  final state = container.read(employeeJobDetailControllerProvider);
  final job = state.job;
  if (job == null) return false;

  final hasPins = collectJobPinEntries(job.levels).isNotEmpty;
  if (hasPins) {
    final incompleteWork = countIncompleteOperativePins(job, state);
    if (incompleteWork > 0) {
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            incompleteWork == 1
                ? 'Complete the remaining pin before finishing this job.'
                : 'Complete all $incompleteWork remaining pins before finishing this job.',
          ),
        ),
      );
      return false;
    }
  } else if (state.formIds.isNotEmpty && !state.allRequiredFormsComplete) {
    context.showTopSnackBar(
      const SnackBar(
        content: Text('Complete all required forms before finishing this job.'),
      ),
    );
    return false;
  }

  try {
    if (isOnline) {
      if (!context.mounted) return false;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Submitting forms…'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      late final JobFormBulkSyncResult syncResult;
      try {
        syncResult = await container
            .read(jobFormSubmissionRepositoryProvider)
            .syncPendingSubmissionsForJob(
              jobId: jobId,
              assignments: job.formAssignments,
            );
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
      if (!context.mounted) return false;
      if (!syncResult.isEmpty) {
        await showOperativeJobFormSyncResultSheet(
          context: context,
          result: syncResult,
        );
      }
      if (syncResult.hasFailures) {
        context.showTopSnackBar(
          SnackBar(
            content: Text(syncResult.summaryMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      await detailController.refreshAttachedForms();
      await detailController.load(jobId: jobId);
    } else {
      final pending = await container
          .read(jobFormSubmissionRepositoryProvider)
          .countUnsyncedSubmissionsForJob(jobId);
      if (pending > 0 && context.mounted) {
        context.showTopSnackBar(
          SnackBar(
            content: Text(
              '$pending saved form(s) will submit when you are back online.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (!context.mounted) return false;
    await context.push(
      EmployeeJobConfirmationPage.path,
      extra: <String, Object?>{
        'jobId': jobId,
        'jobTitle': job.title,
      },
    );
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    context.showTopSnackBar(
      SnackBar(
        content: Text(
          ApiResponseMessage.fromAnyError(
            error,
            genericFallback: 'Could not prepare job completion. Please try again.',
          ),
        ),
      ),
    );
    return false;
  }
}

Future<void> scanOperativeJobQr({
  required BuildContext context,
  required ProviderContainer container,
  required int jobId,
  required bool skipChecklist,
}) async {
  final job = container.read(employeeJobDetailControllerProvider).job;
  if (job == null) return;

  final started = await ensureOperativeJobStartedForForms(
    context: context,
    container: container,
    jobId: jobId,
    job: job,
    skipChecklist: skipChecklist,
  );
  if (!context.mounted || !started) return;

  final scannedQr = await runEmployeeQrScanFlow(
    context,
    container,
    jobId: jobId,
  );
  if (!context.mounted || scannedQr == null) return;

  container.read(employeeJobDetailControllerProvider.notifier).markQrCodeScanned(
        qrCode: scannedQr,
      );
  await container.read(employeeJobDetailControllerProvider.notifier).load(jobId: jobId);
}

Future<bool> ensureOperativeJobStartedForForms({
  required BuildContext context,
  required ProviderContainer container,
  required int jobId,
  required EmployeeJobDetail job,
  required bool skipChecklist,
}) async {
  if (skipChecklist ||
      container.read(employeeJobSessionProvider.notifier).isJobStarted(jobId)) {
    return true;
  }
  final started = await showOperativePinChecklistSheet(
    context: context,
    jobId: jobId,
    items: job.safetyChecklist,
  );
  if (!context.mounted || !started) return false;
  await container.read(employeeJobDetailControllerProvider.notifier).load(jobId: jobId);
  return true;
}

Future<void> openOperativeJobForm({
  required BuildContext context,
  required ProviderContainer container,
  required int jobId,
  required int formId,
}) async {
  final controller =
      container.read(employeeJobDetailControllerProvider.notifier);
  final jobFormId = controller.jobFormIdFor(formId);
  final submissionId = controller.submissionIdFor(formId);

  final submitted = await context.push<bool>(
    EmployeeJobFormPage.path,
    extra: <String, Object?>{
      'formId': formId,
      'jobId': jobId,
      if (jobFormId != null && jobFormId > 0) 'jobFormId': jobFormId,
      if (submissionId != null) 'submissionId': submissionId,
    },
  );
  if (!context.mounted || submitted != true) return;
  unawaited(controller.refreshCompletedForms());

  final refreshed = container.read(employeeJobDetailControllerProvider);
  if (refreshed.allRequiredFormsComplete) {
    await _showFormsCompleteDialog(
      context: context,
      container: container,
      jobId: jobId,
    );
  }
}

Future<void> _showFormsCompleteDialog({
  required BuildContext context,
  required ProviderContainer container,
  required int jobId,
}) async {
  await completeOperativeJob(
    context: context,
    container: container,
    jobId: jobId,
  );
}
