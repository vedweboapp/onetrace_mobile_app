import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_qr_scanner_page.dart';
import 'package:red5/employee_role/jobs/data/job_qr_scan_repository.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_details_page.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/qr_code_details_sheet.dart';

/// Opens the camera, registers the scan with the API, and shows job details.
/// Returns `true` when scan + POST succeeded.
Future<bool> runEmployeeQrScanFlow(
  BuildContext context,
  WidgetRef ref, {
  int? jobId,
  bool navigateOnOpenJob = true,
}) async {
  final code = await openFormQrScanner(context);
  final qrCode = code?.trim();
  if (qrCode == null || qrCode.isEmpty || !context.mounted) return false;

  try {
    final result = await ref.read(jobQrScanRepositoryProvider).processScan(
          qrCode: qrCode,
          jobId: jobId,
        );
    if (!context.mounted) return false;

    context.showTopSnackBar(
      SnackBar(
        content: Text(
          result.registeredWithJob
              ? 'QR ${result.qrCode} linked to job.'
              : 'QR details loaded for ${result.details.title}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final openJob = await showQrCodeDetailsSheet(
      context,
      details: result.details,
      qrCode: result.qrCode,
    );
    if (!context.mounted) return true;

    if (openJob == true && navigateOnOpenJob) {
      context.push(
        EmployeeJobDetailsPage.path,
        extra: <String, Object?>{'jobId': result.details.jobId},
      );
    }

    return true;
  } catch (error) {
    if (!context.mounted) return false;
    context.showTopSnackBar(
      SnackBar(
        content: Text(
          ApiResponseMessage.fromAnyError(
            error,
            genericFallback: 'Could not load QR code details.',
          ),
        ),
      ),
    );
    return false;
  }
}
