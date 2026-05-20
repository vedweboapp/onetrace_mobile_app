import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/network/organization_id_header.dart';
import 'package:red5/features/dashboard/data/organization_settings_models.dart';
import 'package:red5/features/dashboard/data/organization_settings_write.dart';

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

  /// `PUT /organizationsettings/{organizationId}/` with [OrganizationIdHeader].
  ///
  /// Sends `multipart/form-data` when [companyLogoBytes] is set (field
  /// `company_logo`); otherwise JSON.
  Future<OrganizationSettingsModel> updateSettings({
    required int organizationId,
    required OrganizationSettingsWrite body,
    Uint8List? companyLogoBytes,
    String companyLogoFileName = 'company_logo.jpg',
    CancelToken? cancelToken,
  }) async {
    final headers = <String, dynamic>{
      OrganizationIdHeader.name: organizationId.toString(),
    };

    final Response<Map<String, dynamic>> response;
    if (companyLogoBytes != null && companyLogoBytes.isNotEmpty) {
      final filename = companyLogoFileName.trim().isEmpty
          ? 'company_logo.jpg'
          : companyLogoFileName.trim();
      final form = FormData.fromMap({
        ..._formFieldsFromWrite(body),
        'company_logo': MultipartFile.fromBytes(
          companyLogoBytes,
          filename: filename,
        ),
      });
      response = await _dio.put<Map<String, dynamic>>(
        AppApiUrls.organizationSettingsById(organizationId),
        data: form,
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          contentType: 'multipart/form-data',
        ),
      );
    } else {
      response = await _dio.put<Map<String, dynamic>>(
        AppApiUrls.organizationSettingsById(organizationId),
        data: body.toJson(),
        cancelToken: cancelToken,
        options: Options(headers: headers),
      );
    }

    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return OrganizationSettingsModel.fromJson(payload);
  }

  static Map<String, dynamic> _formFieldsFromWrite(
    OrganizationSettingsWrite body,
  ) {
    final fields = <String, dynamic>{};
    for (final entry in body.toJson().entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is List) {
        fields[entry.key] = value;
      } else if (value is String) {
        fields[entry.key] = value;
      } else {
        fields[entry.key] = value.toString();
      }
    }
    return fields;
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
