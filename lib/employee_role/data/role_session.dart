import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/employee_role/data/app_role.dart';

abstract final class RoleSession {
  const RoleSession._();

  static String staticAccessToken(AppRole role) {
    return 'static-role-token-${role.slug}';
  }

  static AppRole? readRole(LocalStorage storage) {
    return AppRole.fromSlug(storage.getString(LocalStorageKeys.authRole));
  }

  static Future<void> persistRole(LocalStorage storage, AppRole role) async {
    await storage.setString(LocalStorageKeys.authRole, role.slug);
  }

  static Future<void> clearRole(LocalStorage storage) async {
    await storage.remove(LocalStorageKeys.authRole);
  }

  static String? homePathForStoredRole(LocalStorage storage) {
    final role = readRole(storage);
    if (role == null) return null;
    return homePathFor(role);
  }

  static String homePathFor(AppRole role) => '/employee-role/${role.slug}';
}
