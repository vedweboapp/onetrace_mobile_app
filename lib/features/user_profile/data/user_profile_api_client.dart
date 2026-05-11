import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';

/// HTTP client for the `/user-profile/` endpoints.
///
/// The list endpoint typically returns the current user's profile as the
/// first (and only) record, so [fetchCurrentProfile] returns the first item
/// it finds. The id from that record is then used for subsequent reads or
/// PATCH updates via [fetchProfile] / [updateProfile].
final class UserProfileApiClient {
  UserProfileApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// `GET /user-profile/` — returns the first profile the API exposes for the
  /// authenticated user. Returns `null` if the API responds with an empty list.
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

  /// `GET /user-profile/{id}/`.
  Future<UserProfileModel> fetchProfile(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppApiUrls.userProfileById(id),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return UserProfileModel.fromJson(payload);
  }

  /// `PATCH /user-profile/{id}/` — partial update.
  ///
  /// All parameters are optional; only fields that are non-null in the call
  /// site are forwarded to the API so we can support both "edit a single
  /// field" and "save the entire form" flows from the same method.
  ///
  /// Fields are sent both at the top level and nested under `user_detail` to
  /// accommodate either a flat or nested serializer on the backend.
  Future<UserProfileModel> updateProfile({
    required String id,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? gender,
    String? role,
    String? dateOfBirth,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? country,
    String? postalCode,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.userProfileById(id),
      data: _profilePayload(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        gender: gender,
        role: role,
        dateOfBirth: dateOfBirth,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: state,
        country: country,
        postalCode: postalCode,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return UserProfileModel.fromJson(payload);
  }

  /// Identical to [updateProfile] but issues a full `PUT` instead of `PATCH`.
  Future<UserProfileModel> replaceProfile({
    required String id,
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String gender,
    String role = '',
    String dateOfBirth = '',
    String addressLine1 = '',
    String addressLine2 = '',
    String city = '',
    String state = '',
    String country = '',
    String postalCode = '',
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      AppApiUrls.userProfileById(id),
      data: _profilePayload(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        gender: gender,
        role: role,
        dateOfBirth: dateOfBirth,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: state,
        country: country,
        postalCode: postalCode,
      ),
    );
    final root = response.data ?? const <String, dynamic>{};
    final data = _readMap(root['data']);
    final payload = data.isNotEmpty ? data : root;
    return UserProfileModel.fromJson(payload);
  }

  static Map<String, dynamic> _profilePayload({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? gender,
    String? role,
    String? dateOfBirth,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? country,
    String? postalCode,
  }) {
    final userDetail = <String, dynamic>{};
    final top = <String, dynamic>{};

    void put(String key, String? value) {
      if (value == null) return;
      top[key] = value;
      userDetail[key] = value;
    }

    void putTop(String key, String? value) {
      if (value == null) return;
      top[key] = value;
    }

    put('first_name', firstName);
    put('last_name', lastName);
    put('email', email);
    put('phone_number', phoneNumber);
    put('gender', gender);

    putTop('role', role);
    putTop('date_of_birth', dateOfBirth);
    putTop('address_line_1', addressLine1);
    putTop('address_line_2', addressLine2);
    putTop('city', city);
    putTop('state', state);
    putTop('country', country);
    putTop('postal_code', postalCode);

    if (userDetail.isNotEmpty) {
      top['user_detail'] = userDetail;
    }
    return top;
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
