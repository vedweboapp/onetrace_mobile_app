import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/network/auth_bearer_interceptor.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_client.dart';

final crmQuotesApiProvider = Provider<CrmQuotesApi>((ref) {
  final storage = ref.read(localStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppApiUrls.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {
        Headers.acceptHeader: Headers.jsonContentType,
        Headers.contentTypeHeader: Headers.jsonContentType,
      },
    ),
  );
  dio.interceptors.addAll([
    AuthBearerInterceptor(storage),
    ApiDioLogInterceptor(),
  ]);
  return CrmQuotesApiClient(dio: dio);
});
