import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/utils/qr_code_utils.dart';
import 'package:red5/employee_role/jobs/data/employee_job_forms_api_client.dart';
import 'package:red5/employee_role/jobs/data/qr_code_details_models.dart';
import 'package:red5/features/dashboard/data/qr_codes_api_client.dart';

final jobQrScanRepositoryProvider = Provider<JobQrScanRepository>((ref) {
  return JobQrScanRepository(
    qrCodesApi: sl<QrCodesApiClient>(),
    jobFormsApi: sl<EmployeeJobFormsApiClient>(),
    connectivity: sl<ConnectivityService>(),
  );
});

final class JobQrScanResult {
  const JobQrScanResult({
    required this.details,
    required this.registeredWithJob,
    required this.qrCode,
  });

  final QrCodeJobDetails details;
  final bool registeredWithJob;
  final String qrCode;
}

final class JobQrScanRepository {
  JobQrScanRepository({
    required QrCodesApiClient qrCodesApi,
    required EmployeeJobFormsApiClient jobFormsApi,
    required ConnectivityService connectivity,
  })  : _qrCodesApi = qrCodesApi,
        _jobFormsApi = jobFormsApi,
        _connectivity = connectivity;

  final QrCodesApiClient _qrCodesApi;
  final EmployeeJobFormsApiClient _jobFormsApi;
  final ConnectivityService _connectivity;

  /// Registers the scan on a job (`POST .../scan-qr/`) and loads public details.
  ///
  /// When [jobId] is set (job completion / job details), the POST runs first so
  /// the operative job is linked even if the public details lookup is slow.
  Future<JobQrScanResult> processScan({
    required String qrCode,
    int? jobId,
  }) async {
    final normalized = QrCodeUtils.normalizeScannedValue(qrCode);
    if (normalized.isEmpty) {
      throw ArgumentError('QR code is empty');
    }
    if (!_connectivity.isOnline) {
      throw const JobQrScanOfflineException();
    }

    var registered = false;
    final activeJobId = jobId;

    if (activeJobId != null && activeJobId > 0) {
      await _jobFormsApi.scanJobQr(jobId: activeJobId, qrCode: normalized);
      registered = true;
    }

    QrCodeJobDetails details;
    try {
      details = await _qrCodesApi.fetchQrCodeDetails(normalized);
    } on DioException catch (error) {
      if (registered && activeJobId != null && activeJobId > 0) {
        details = QrCodeJobDetails(
          jobId: activeJobId,
          title: 'Job',
          qrCode: normalized,
        );
      } else {
        rethrow;
      }
    }

    if (!registered && details.jobId > 0) {
      await _jobFormsApi.scanJobQr(jobId: details.jobId, qrCode: normalized);
      registered = true;
    }

    return JobQrScanResult(
      details: details,
      registeredWithJob: registered,
      qrCode: normalized,
    );
  }
}

final class JobQrScanOfflineException implements Exception {
  const JobQrScanOfflineException();

  @override
  String toString() => 'Connect to the internet to scan QR codes.';
}

bool isJobQrScanNetworkError(Object error) {
  if (error is JobQrScanOfflineException) return true;
  if (error is DioException) {
    final type = error.type;
    return type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout;
  }
  return false;
}
