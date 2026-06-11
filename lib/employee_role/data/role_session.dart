import 'package:red5/core/auth/user_role_navigation.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/employee_role/data/app_role.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';

abstract final class RoleSession {
  const RoleSession._();

  static String staticAccessToken(AppRole role) {
    return 'static-role-token-${role.slug}';
  }

  /// Role display name from `/user-profile/` (e.g. `Technician`, `Admin`).
  static String? readRoleName(LocalStorage storage) {
    return storage.getString(LocalStorageKeys.authRole)?.trim();
  }

  /// Maps stored role name/slug to [AppRole] for legacy UI helpers.
  static AppRole? readRole(LocalStorage storage) {
    final stored = readRoleName(storage);
    if (stored == null || stored.isEmpty) return null;
    return AppRole.fromRoleName(stored) ?? AppRole.fromSlug(stored);
  }

  static AppShell readAppShell(LocalStorage storage) {
    final roleName = readRoleName(storage);
    if (roleName == null || roleName.isEmpty) return AppShell.admin;
    return UserRoleNavigation.shellForRoleName(roleName);
  }

  /// Persists API [`role_detail.role_name`] for redirect guards.
  static Future<void> persistRoleName(
    LocalStorage storage,
    String roleName,
  ) async {
    final trimmed = roleName.trim();
    if (trimmed.isEmpty) {
      await clearRole(storage);
      return;
    }
    await storage.setString(LocalStorageKeys.authRole, trimmed);
  }

  /// Static demo accounts — stores human-readable role label.
  static Future<void> persistRole(LocalStorage storage, AppRole role) async {
    await persistRoleName(storage, role.label);
  }

  static Future<void> clearRole(LocalStorage storage) async {
    await storage.remove(LocalStorageKeys.authRole);
  }

  static String homePathForStoredRole(LocalStorage storage) {
    final roleName = readRoleName(storage);
    if (roleName == null || roleName.isEmpty) {
      return DashboardPage.homePath;
    }
    return UserRoleNavigation.homePathForRoleName(roleName);
  }

  @Deprecated('Use UserRoleNavigation.homePathForRoleName with profile role name.')
  static String homePathFor(AppRole role) {
    return UserRoleNavigation.homePathForRoleName(role.label);
  }
}
