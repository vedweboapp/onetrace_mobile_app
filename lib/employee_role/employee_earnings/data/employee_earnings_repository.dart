import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/employee_role/employee_earnings/data/employee_earnings_api_client.dart';
import 'package:red5/employee_role/employee_earnings/data/employee_earnings_models.dart';

final employeeEarningsApiClientProvider = Provider<EmployeeEarningsApiClient>(
  (ref) => sl<EmployeeEarningsApiClient>(),
);

final employeeEarningsRepositoryProvider = Provider<EmployeeEarningsRepository>(
  (ref) => EmployeeEarningsRepository(
    apiClient: ref.read(employeeEarningsApiClientProvider),
    localStorage: ref.read(localStorageProvider),
  ),
);

final employeeEarningsProvider = FutureProvider<EmployeeEarningsListResponse>(
  (ref) => ref
      .read(employeeEarningsRepositoryProvider)
      .fetchEarningsForCurrentWorker(),
);

class EmployeeEarningsRepository {
  EmployeeEarningsRepository({
    required this.apiClient,
    required this.localStorage,
  });

  final EmployeeEarningsApiClient apiClient;
  final LocalStorage localStorage;

  Future<EmployeeEarningsListResponse> fetchEarningsForCurrentWorker() async {
    final workerIdValue = localStorage
        .getString(LocalStorageKeys.authUserId)
        ?.trim();
    if (workerIdValue == null || workerIdValue.isEmpty) {
      return const EmployeeEarningsListResponse(
        summary: EmployeeEarningsSummary(
          totalJobs: 0,
          totalEarning: 0,
          paidAmount: 0,
          unpaidAmount: 0,
        ),
        jobs: <EmployeeEarningJob>[],
      );
    }
    final workerId = int.tryParse(workerIdValue);
    if (workerId == null || workerId <= 0) {
      return const EmployeeEarningsListResponse(
        summary: EmployeeEarningsSummary(
          totalJobs: 0,
          totalEarning: 0,
          paidAmount: 0,
          unpaidAmount: 0,
        ),
        jobs: <EmployeeEarningJob>[],
      );
    }

    return apiClient.fetchEarnings(workerId: workerId);
  }
}
