import 'package:dio/dio.dart';
import 'package:red5/core/network/organization_id_header.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';

/// Adds [OrganizationIdHeader.name] from [LocalStorage] when set.
final class OrganizationIdInterceptor extends Interceptor {
  OrganizationIdInterceptor(this._storage);

  final LocalStorage _storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final fromStorage = _storage.getInt(LocalStorageKeys.authOrganizationId) ??
        int.tryParse(
          _storage.getString(LocalStorageKeys.authOrganizationId)?.trim() ?? '',
        );
    if (fromStorage != null &&
        !options.headers.containsKey(OrganizationIdHeader.name)) {
      options.headers[OrganizationIdHeader.name] = fromStorage.toString();
    }
    handler.next(options);
  }
}
