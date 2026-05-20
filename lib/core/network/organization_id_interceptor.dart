import 'package:dio/dio.dart';
import 'package:red5/core/network/organization_id_header.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/organization_id_storage.dart';

/// Adds [OrganizationIdHeader.name] from [LocalStorage] when set.
final class OrganizationIdInterceptor extends Interceptor {
  OrganizationIdInterceptor(this._storage);

  final LocalStorage _storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final fromStorage = OrganizationIdStorage.read(_storage);
    if (fromStorage != null &&
        !options.headers.containsKey(OrganizationIdHeader.name)) {
      options.headers[OrganizationIdHeader.name] = fromStorage.toString();
    }
    handler.next(options);
  }
}
