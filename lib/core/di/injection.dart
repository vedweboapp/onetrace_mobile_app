import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/network/auth_bearer_interceptor.dart';
import 'package:red5/core/network/dio_multipart_transfer.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/contacts/data/contacts_api_client.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api.dart';
import 'package:red5/features/groups/data/groups_api_client.dart';
import 'package:red5/features/dashboard/data/invite_user_service.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_client.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';

final GetIt sl = GetIt.instance;

/// Registers app-wide singletons. Call once after [LocalStorage] is ready
/// (e.g. from [main] after `SharedPreferencesStorage.create()`).
Future<void> configureDependencies({required LocalStorage localStorage}) async {
  await sl.reset();
  sl.registerSingleton<LocalStorage>(localStorage);

  sl.registerLazySingleton<AuthApiClient>(() {
    final storage = sl<LocalStorage>();
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
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    dio.interceptors.addAll([
      AuthBearerInterceptor(storage),
      ApiDioLogInterceptor(),
    ]);
    return AuthApiClient(dio: dio);
  });

  sl.registerLazySingleton<CrmQuotesApi>(() {
    final storage = sl<LocalStorage>();
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

  sl.registerLazySingleton<ClientsApiClient>(() {
    final storage = sl<LocalStorage>();
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
    return ClientsApiClient(dio: dio);
  });

  sl.registerLazySingleton<SitesApiClient>(() {
    final storage = sl<LocalStorage>();
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
    return SitesApiClient(dio: dio);
  });

  sl.registerLazySingleton<ContactsApiClient>(() {
    final storage = sl<LocalStorage>();
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
    return ContactsApiClient(dio: dio);
  });

  sl.registerLazySingleton<GroupsApiClient>(() {
    final storage = sl<LocalStorage>();
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
    return GroupsApiClient(dio: dio);
  });

  sl.registerLazySingleton<QuoteProjectApiClient>(() {
    final storage = sl<LocalStorage>();
    final dio = Dio(
      BaseOptions(
        baseUrl: AppApiUrls.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
        headers: const {Headers.acceptHeader: Headers.jsonContentType},
      ),
    );
    dio.interceptors.addAll([
      AuthBearerInterceptor(storage),
      ApiDioLogInterceptor(),
    ]);
    return QuoteProjectApiClient(dio: dio);
  });

  sl.registerLazySingleton<UserProfileApiClient>(() {
    final storage = sl<LocalStorage>();
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
    return UserProfileApiClient(dio: dio);
  });

  sl.registerLazySingleton<DioMultipartTransfer>(DioMultipartTransfer.new);

  sl.registerLazySingleton<InviteUserService>(
    () => InviteUserApiService(sl<AuthApiClient>()),
  );
}
