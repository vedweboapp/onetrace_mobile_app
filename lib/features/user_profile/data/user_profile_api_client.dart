import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';

/// HTTP client for the `/user-profile/` endpoints.
///
/// Profile updates use `PATCH /user-profile/{id}/` with nested JSON:
/// `user_detail`, `emails`, `phones`, `addresses`.
/// Optional `user_image` is sent as a second multipart PATCH.
final class UserProfileApiClient {
  UserProfileApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static Options get _jsonOptions => Options(
        contentType: Headers.jsonContentType,
        headers: const <String, dynamic>{
          Headers.acceptHeader: Headers.jsonContentType,
        },
      );

  /// Loads every page of `GET /user-profile/` until exhausted (for pickers).
  Future<List<UserProfileModel>> fetchAllUserProfiles({
    int pageSize = 50,
  }) async {
    final out = <UserProfileModel>[];
    final seenIds = <String>{};
    var page = 1;
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        AppApiUrls.userProfiles,
        queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
      );
      final root = response.data ?? const <String, dynamic>{};
      final rows = _readRows(root);
      for (final row in rows) {
        final m = UserProfileModel.fromJson(row);
        if (m.id.isEmpty || !seenIds.add(m.id)) continue;
        out.add(m);
      }
      final pagination = _readMap(root['pagination']);
      final hasNext = pagination['next'] != null;
      if (!hasNext || rows.isEmpty) break;
      page++;
    }
    if (out.isEmpty) {
      final single = await fetchCurrentProfile();
      if (single != null) out.add(single);
    }
    return out;
  }

  /// `GET /user-profile/` — first row (or single `data` object).
  Future<UserProfileModel?> fetchCurrentProfile() async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.userProfiles,
    );
    final root = response.data ?? const <String, dynamic>{};
    final rows = _readRows(root);
    if (rows.isEmpty) {
      final data = _readMap(root['data']);
      if (data.isEmpty) return null;
      return UserProfileModel.fromJson(data);
    }
    return UserProfileModel.fromJson(rows.first);
  }

  /// `GET /user-profile/{id}/` — full record including nested ids.
  Future<UserProfileModel> fetchProfile(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.userProfileById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return UserProfileModel.fromJson(payload);
  }

  /// `PATCH /user-profile/{id}/` — nested JSON write body (single request).
  ///
  /// ```json
  /// {
  ///   "user_detail": { "first_name", "last_name", "date_of_birth", "gender" },
  ///   "emails": [{ "id?", "email", "is_primary" }],
  ///   "phones": [{ "id?", "phone", "is_primary" }],
  ///   "addresses": [{ "id?", "address_1", "address_2", "country", "state",
  ///                   "city", "pincode", "is_primary" }]
  /// }
  /// ```
  Future<UserProfileModel> replaceProfile({
    required String id,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    required List<Map<String, dynamic>> emails,
    required List<Map<String, dynamic>> phones,
    required List<Map<String, dynamic>> addresses,
    List<int>? profileImageBytes,
    String? profileImageFilename,
  }) async {
    final payload = <String, dynamic>{
      'user_detail': <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'gender': gender,
        if (dateOfBirth.trim().isNotEmpty) 'date_of_birth': dateOfBirth.trim(),
      },
      'emails': emails,
      'phones': phones,
      'addresses': addresses,
    };

    final hasImage =
        profileImageBytes != null && profileImageBytes.isNotEmpty;

    final Response<Map<String, dynamic>> response;
    if (hasImage) {
      final name = (profileImageFilename ?? 'profile.jpg').trim().isEmpty
          ? 'profile.jpg'
          : profileImageFilename!.trim();
      final form = FormData();
      form.fields.add(MapEntry('user_detail', jsonEncode(payload['user_detail'])));
      form.fields.add(MapEntry('emails', jsonEncode(emails)));
      form.fields.add(MapEntry('phones', jsonEncode(phones)));
      form.fields.add(MapEntry('addresses', jsonEncode(addresses)));
      form.files.add(
        MapEntry(
          'user_image',
          MultipartFile.fromBytes(profileImageBytes, filename: name),
        ),
      );
      response = await _dio.patch<Map<String, dynamic>>(
        AppApiUrls.userProfileById(id),
        data: form,
        options: Options(
          contentType:
              '${Headers.multipartFormDataContentType}; boundary=${form.boundary}',
          headers: const <String, dynamic>{
            Headers.acceptHeader: Headers.jsonContentType,
          },
        ),
      );
    } else {
      // One PATCH — real nested JSON (not form-encoded strings).
      response = await _dio.patch<Map<String, dynamic>>(
        AppApiUrls.userProfileById(id),
        data: jsonEncode(payload),
        options: _jsonOptions,
      );
    }
    return _parseProfileResponse(response.data);
  }

  /// Builds one `emails[]` row for PATCH.
  static Map<String, dynamic> emailWrite({
    String? id,
    required String email,
    required bool isPrimary,
  }) {
    final m = <String, dynamic>{'email': email, 'is_primary': isPrimary};
    final idVal = _jsonId(id);
    if (idVal != null) m['id'] = idVal;
    return m;
  }

  /// Builds one `phones[]` row for PATCH.
  static Map<String, dynamic> phoneWrite({
    String? id,
    required String phone,
    required bool isPrimary,
  }) {
    final m = <String, dynamic>{'phone': phone, 'is_primary': isPrimary};
    final idVal = _jsonId(id);
    if (idVal != null) m['id'] = idVal;
    return m;
  }

  /// Builds one `addresses[]` row for PATCH.
  static Map<String, dynamic> addressWrite({
    String? id,
    required String address1,
    required String address2,
    String country = '',
    required String city,
    required String state,
    required String pincode,
    required bool isPrimary,
  }) {
    final m = <String, dynamic>{
      'address_1': address1,
      'address_2': address2,
      'country': country,
      'state': state,
      'city': city,
      'pincode': pincode,
      'is_primary': isPrimary,
    };
    final idVal = _jsonId(id);
    if (idVal != null) m['id'] = idVal;
    return m;
  }

  static UserProfileModel _parseProfileResponse(Map<String, dynamic>? root) {
    final r = root ?? const <String, dynamic>{};
    final data = _readMap(r['data']);
    final payload = data.isNotEmpty ? data : r;
    return UserProfileModel.fromJson(payload);
  }

  static Object? _jsonId(String? id) {
    final t = id?.trim() ?? '';
    if (t.isEmpty) return null;
    return int.tryParse(t) ?? t;
  }

  static List<Map<String, dynamic>> _readRows(Map<String, dynamic> root) {
    final raw = root['data'] ?? root['results'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _readMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }
}

final userProfileApiClientProvider = Provider<UserProfileApiClient>(
  (ref) => sl<UserProfileApiClient>(),
);
