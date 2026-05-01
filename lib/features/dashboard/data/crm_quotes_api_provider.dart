import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/config/app_static_config.dart';
import 'package:red5/core/network/app_http_client.dart';
import 'package:red5/core/network/dio_app_http_client.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api.dart';
import 'package:red5/features/dashboard/data/static_crm_quotes_api.dart';
import 'package:red5/features/dashboard/data/zoho_api_config.dart';
import 'package:red5/features/dashboard/data/zoho_crm_quotes_api.dart';

final appHttpClientProvider = Provider<AppHttpClient>((ref) {
  return DioAppHttpClient();
});

final zohoApiConfigProvider = Provider<ZohoApiConfig>((ref) {
  return const ZohoApiConfig();
});

final crmQuotesApiProvider = Provider<CrmQuotesApi>((ref) {
  if (AppStaticConfig.useStaticPreview) {
    return const StaticCrmQuotesApi();
  }
  return ZohoCrmQuotesApi(
    http: ref.watch(appHttpClientProvider),
    config: ref.watch(zohoApiConfigProvider),
  );
});
