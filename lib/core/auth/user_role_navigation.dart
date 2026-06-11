import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/employee_role/data/role_session.dart';
import 'package:red5/employee_role/employee_home/employee_home_page.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';

/// Which app shell the signed-in user should see after login.
enum AppShell {
  admin,
  employee,
}

/// Resolves post-login navigation from `/user-profile/` [`role_detail`].
abstract final class UserRoleNavigation {
  const UserRoleNavigation._();

  /// Reads [`UserProfileModel.roleDetail.roleName`] when present.
  static String roleNameFromProfile(UserProfileModel profile) {
    return profile.roleDetail?.roleName.trim() ?? '';
  }

  /// `role_detail == null` → admin; otherwise route by [`role_detail.role_name`].
  static AppShell shellForProfile(UserProfileModel profile) {
    if (profile.roleDetail == null) return AppShell.admin;
    return shellForRoleName(profile.roleDetail!.roleName);
  }

  /// Admin → dashboard; technician, manager, site (and other non-admin) → employee home.
  static AppShell shellForRoleName(String? roleName) {
    if (_isAdminRoleName(roleName)) return AppShell.admin;
    return AppShell.employee;
  }

  static bool _isAdminRoleName(String? roleName) {
    final normalized = roleName?.trim().toLowerCase() ?? '';
    return normalized == 'admin' || normalized == 'administrator';
  }

  static String homePathForShell(AppShell shell) {
    switch (shell) {
      case AppShell.admin:
        return DashboardPage.homePath;
      case AppShell.employee:
        return TechnicianHomePage.path;
    }
  }

  static String homePathForProfile(UserProfileModel profile) {
    return homePathForShell(shellForProfile(profile));
  }

  static String homePathForRoleName(String roleName) {
    return homePathForShell(shellForRoleName(roleName));
  }

  /// Fetches the current user's profile, persists role name, returns home route.
  static Future<String> resolveAndPersistHomePath({
    required LocalStorage storage,
    required UserProfileApiClient profileClient,
  }) async {
    final profile = await _fetchProfile(profileClient, storage);
    if (profile == null) {
      return RoleSession.homePathForStoredRole(storage);
    }

    if (profile.roleDetail == null) {
      await RoleSession.clearRole(storage);
      return DashboardPage.homePath;
    }

    final roleName = roleNameFromProfile(profile);
    if (roleName.isNotEmpty) {
      await RoleSession.persistRoleName(storage, roleName);
    } else {
      await RoleSession.clearRole(storage);
    }
    return homePathForProfile(profile);
  }

  static Future<UserProfileModel?> _fetchProfile(
    UserProfileApiClient client,
    LocalStorage storage,
  ) async {
    final userId = storage.getString(LocalStorageKeys.authUserId)?.trim();
    if (userId != null && userId.isNotEmpty) {
      try {
        return await client.fetchProfile(userId);
      } catch (_) {
        // Fall through to list/current profile.
      }
    }
    return client.fetchCurrentProfile();
  }
}
