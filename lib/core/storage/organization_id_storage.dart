import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';

/// Persists and reads the active organization id for [OrganizationIdHeader].
abstract final class OrganizationIdStorage {
  OrganizationIdStorage._();

  static int? read(LocalStorage storage) {
    final stored = storage.getInt(LocalStorageKeys.authOrganizationId);
    if (stored != null) return stored;
    final raw = storage.getString(LocalStorageKeys.authOrganizationId)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  static Future<void> persist(LocalStorage storage, int? organizationId) async {
    if (organizationId != null && organizationId > 0) {
      await storage.setInt(LocalStorageKeys.authOrganizationId, organizationId);
    } else {
      await storage.remove(LocalStorageKeys.authOrganizationId);
    }
  }
}
