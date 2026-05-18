import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/network/organization_id_header.dart';
import 'package:red5/features/dashboard/data/organization_settings_models.dart';

final class OrganizationSettingsApiClient {
  OrganizationSettingsApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `GET /organizationsettings/{organizationId}/` with [OrganizationIdHeader].
  Future<OrganizationSettingsModel> fetchSettings({
    required int organizationId,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.organizationSettingsById(organizationId),
      cancelToken: cancelToken,
      options: Options(
        headers: <String, dynamic>{
          OrganizationIdHeader.name: organizationId.toString(),
        },
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return OrganizationSettingsModel.fromJson(payload);
  }
}

Map<String, dynamic> _readMap(dynamic raw) {
  if (raw is! Map) return const {};
  return Map<String, dynamic>.from(
    raw.map((k, v) => MapEntry(k.toString(), v)),
  );
}

final organizationSettingsApiClientProvider =
    Provider<OrganizationSettingsApiClient>(
  (ref) => sl<OrganizationSettingsApiClient>(),
);
