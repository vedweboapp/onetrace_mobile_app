import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/database/technician_form_database.dart';
import 'package:red5/core/notifications/app_notifications_controller.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/employee_role/data/role_session.dart';
import 'package:red5/employee_role/employee_earnings/data/employee_earnings_repository.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_jobs_controller.dart';
import 'package:red5/employee_role/jobs/application/operative_last_working_pin.dart';
import 'package:red5/employee_role/offline/operative_offline_store.dart';
import 'package:red5/employee_role/projects/application/employee_projects_controller.dart';

/// Clears the signed-in technician/admin local session (timers, jobs, cache).
abstract final class SignedInSessionCleanup {
  const SignedInSessionCleanup._();

  static Future<void> clearPersisted(LocalStorage storage) async {
    await storage.remove(LocalStorageKeys.employeeJobTimerStarts);
    await storage.remove(LocalStorageKeys.employeeJobTimerPaused);
    await storage.remove(LocalStorageKeys.employeeJobTimerCompleted);
    await storage.remove(LocalStorageKeys.employeeJobSafetyVerified);
    await storage.remove(LocalStorageKeys.appNotifications);
    await storage.remove(LocalStorageKeys.appKnownAssignedJobIds);
    await storage.remove(LocalStorageKeys.appAssignmentTrackingReady);
    await storage.remove(LocalStorageKeys.authAccessToken);
    await storage.remove(LocalStorageKeys.authRefreshToken);
    await storage.remove(LocalStorageKeys.authUserId);
    await storage.remove(LocalStorageKeys.authOrganizationId);
    await RoleSession.clearRole(storage);
    await OperativeLastWorkingPin.clearAll();
    try {
      await sl<TechnicianFormDatabase>().clearUserSessionCache();
    } catch (_) {
      // Database may not be ready yet (cold splash).
    }
  }

  static Future<void> clear(WidgetRef ref) async {
    await ref.read(employeeJobSessionProvider.notifier).clearForLogout();
    ref.read(employeeJobsControllerProvider.notifier).clearForLogout();
    ref.read(employeeProjectsControllerProvider.notifier).clearForLogout();
    await ref.read(appNotificationsControllerProvider.notifier).clearForLogout();
    try {
      await ref.read(operativeOfflineStoreProvider).clearUserSession();
    } catch (_) {}
    ref.invalidate(employeeEarningsProvider);
    await clearPersisted(ref.read(localStorageProvider));
  }
}
