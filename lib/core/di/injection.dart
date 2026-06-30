import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:red5/core/network/api_dio_log_interceptor.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/network/auth_bearer_interceptor.dart';
import 'package:red5/core/network/organization_id_interceptor.dart';
import 'package:red5/core/network/dio_multipart_transfer.dart';
import 'package:red5/core/network/success_toast_interceptor.dart';
import 'package:red5/core/database/technician_form_database.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/core/auth/auth_redirect_notifier.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/contacts/data/contacts_api_client.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api.dart';
import 'package:red5/features/groups/data/groups_api_client.dart';
import 'package:red5/features/items/data/items_api_client.dart';
import 'package:red5/features/dashboard/data/invoices_api_client.dart';
import 'package:red5/features/quotations/data/quotations_api_client.dart';
import 'package:red5/features/dashboard/data/invite_user_service.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_client.dart';
import 'package:red5/features/dashboard/data/organization_settings_api_client.dart';
import 'package:red5/features/dashboard/data/qr_codes_api_client.dart';
import 'package:red5/features/forms/data/forms_api_client.dart';
import 'package:red5/employee_role/forms/data/operative_project_forms_api_client.dart';
import 'package:red5/employee_role/jobs/data/employee_job_forms_api_client.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';
import 'package:red5/features/user_profile/data/roles_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/features/dashboard/data/zoho_integration_api_client.dart';
import 'package:red5/features/vendors/data/vendors_api_client.dart';
import 'package:red5/features/dashboard/data/purchase_orders_api_client.dart';

final GetIt sl = GetIt.instance;

List<Interceptor> _authorizedDioInterceptors(LocalStorage storage) => [
  AuthBearerInterceptor(storage),
  OrganizationIdInterceptor(storage),
  ApiDioLogInterceptor(),
  SuccessToastInterceptor(),
];

/// Registers app-wide singletons. Call once after [LocalStorage] is ready
/// (e.g. from [main] after `SharedPreferencesStorage.create()`).
Future<void> configureDependencies({required LocalStorage localStorage}) async {
  await sl.reset();
  sl.registerSingleton<LocalStorage>(localStorage);
  sl.registerSingleton<AuthRedirectNotifier>(AuthRedirectNotifier());
  sl.registerSingleton<ConnectivityService>(ConnectivityService());
  sl.registerSingletonAsync<TechnicianFormDatabase>(
    TechnicianFormDatabase.open,
  );
  await sl.isReady<TechnicianFormDatabase>();

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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return ClientsApiClient(dio: dio);
  });

  sl.registerLazySingleton<VendorsApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return VendorsApiClient(dio: dio);
  });

  sl.registerLazySingleton<PurchaseOrdersApiClient>(() {
    final storage = sl<LocalStorage>();
    final dio = Dio(
      BaseOptions(
        baseUrl: AppApiUrls.purchaseOrdersBaseUrl,
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return PurchaseOrdersApiClient(dio: dio);
  });

  sl.registerLazySingleton<ZohoIntegrationApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return ZohoIntegrationApiClient(dio: dio);
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
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
        followRedirects: true,
        headers: const {
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return GroupsApiClient(dio: dio);
  });

  sl.registerLazySingleton<ItemsApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return ItemsApiClient(dio: dio);
  });

  sl.registerLazySingleton<QuotationsApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return QuotationsApiClient(dio: dio);
  });

  sl.registerLazySingleton<InvoicesApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return InvoicesApiClient(dio: dio);
  });

  sl.registerLazySingleton<EmployeeJobFormsApiClient>(() {
    final storage = sl<LocalStorage>();
    final dio = Dio(
      BaseOptions(
        baseUrl: AppApiUrls.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: const {
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
    );
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return EmployeeJobFormsApiClient(dio: dio);
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return QuoteProjectApiClient(dio: dio);
  });

  sl.registerLazySingleton<RolesApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return RolesApiClient(dio: dio);
  });

  sl.registerLazySingleton<OrganizationSettingsApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return OrganizationSettingsApiClient(dio: dio);
  });

  sl.registerLazySingleton<FormsApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return FormsApiClient(dio: dio);
  });

  sl.registerLazySingleton<OperativeProjectFormsApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return OperativeProjectFormsApiClient(dio: dio);
  });

  sl.registerLazySingleton<QrCodesApiClient>(() {
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
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    final publicDio = Dio(
      BaseOptions(
        baseUrl: AppApiUrls.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {Headers.acceptHeader: Headers.jsonContentType},
      ),
    );
    return QrCodesApiClient(dio: dio, publicDio: publicDio);
  });

  sl.registerLazySingleton<UserProfileApiClient>(() {
    final storage = sl<LocalStorage>();
    final dio = Dio(
      BaseOptions(
        baseUrl: AppApiUrls.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {Headers.acceptHeader: Headers.jsonContentType},
      ),
    );
    dio.interceptors.addAll(_authorizedDioInterceptors(storage));
    return UserProfileApiClient(dio: dio);
  });

  sl.registerLazySingleton<DioMultipartTransfer>(DioMultipartTransfer.new);

  sl.registerLazySingleton<InviteUserService>(
    () => InviteUserApiService(sl<AuthApiClient>()),
  );
}
