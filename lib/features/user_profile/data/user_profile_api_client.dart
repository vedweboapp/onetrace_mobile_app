import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';

/// HTTP client for the `/user-profile/` endpoints.
///
/// Reads follow `GET` list/detail. Full update uses a flat **UserProfileWrite**
/// body: `email`, `first_name`, `last_name`, `phone_number`, `gender`, `role`,
/// `address1`, `address2`. Optional `user_image` is sent as multipart when
/// [profileImageBytes] is non-empty.
final class UserProfileApiClient {
  UserProfileApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static Options get _jsonWriteOptions => Options(
        headers: const <String, dynamic>{
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      );

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

  /// `PATCH /user-profile/{id}/` — only keys with non-null args are sent.
  Future<UserProfileModel> updateProfile({
    required String id,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? gender,
    List<Map<String, dynamic>>? communications,
    List<Map<String, dynamic>>? addresses,
  }) async {
    final body = _userWritePatchBody(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      gender: gender,
      communications: communications,
      addresses: addresses,
    );
    final response = await _dio.patch<Map<String, dynamic>>(
      AppApiUrls.userProfileById(id),
      data: body,
      options: _jsonWriteOptions,
    );
    return _parseProfileResponse(response.data);
  }

  /// `PUT /user-profile/{id}/` — flat body + optional profile image (multipart).
  Future<UserProfileModel> replaceProfile({
    required String id,
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String gender,
    required int role,
    required String address1,
    required String address2,
    List<int>? profileImageBytes,
    String? profileImageFilename,
  }) async {
    final flat = <String, dynamic>{
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'gender': gender,
      'role': role,
      'address1': address1,
      'address2': address2,
    };

    final Response<Map<String, dynamic>> response;
    if (profileImageBytes != null && profileImageBytes.isNotEmpty) {
      final name = (profileImageFilename ?? 'profile.jpg').trim().isEmpty
          ? 'profile.jpg'
          : profileImageFilename!.trim();
      final form = FormData.fromMap({
        ...flat,
        'user_image': MultipartFile.fromBytes(
          profileImageBytes,
          filename: name,
        ),
      });
      response = await _dio.put<Map<String, dynamic>>(
        AppApiUrls.userProfileById(id),
        data: form,
        options: Options(
          headers: const <String, dynamic>{
            Headers.acceptHeader: Headers.jsonContentType,
          },
        ),
      );
    } else {
      response = await _dio.put<Map<String, dynamic>>(
        AppApiUrls.userProfileById(id),
        data: flat,
        options: _jsonWriteOptions,
      );
    }
    return _parseProfileResponse(response.data);
  }

  static UserProfileModel _parseProfileResponse(Map<String, dynamic>? root) {
    final r = root ?? const <String, dynamic>{};
    final data = _readMap(r['data']);
    final payload = data.isNotEmpty ? data : r;
    return UserProfileModel.fromJson(payload);
  }

  static Map<String, dynamic> _userWritePatchBody({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? gender,
    List<Map<String, dynamic>>? communications,
    List<Map<String, dynamic>>? addresses,
  }) {
    final m = <String, dynamic>{};
    if (firstName != null) m['first_name'] = firstName;
    if (lastName != null) m['last_name'] = lastName;
    if (phoneNumber != null) m['phone_number'] = phoneNumber;
    if (gender != null) m['gender'] = gender;
    if (communications != null) m['communications'] = communications;
    if (addresses != null) m['addresses'] = addresses;
    return m;
  }

  /// One `communications` element for PATCH (optional server `id`).
  static Map<String, dynamic> communicationWrite({
    String? id,
    required String phone,
    required String email,
    required bool isPrimary,
  }) {
    final m = <String, dynamic>{
      'phone': phone,
      'email': email,
      'is_primary': isPrimary,
    };
    final idVal = _jsonId(id);
    if (idVal != null) m['id'] = idVal;
    return m;
  }

  /// One `addresses` element for PATCH (optional server `id`).
  static Map<String, dynamic> addressWrite({
    String? id,
    required String address1,
    required String address2,
    required String city,
    required String state,
    required String pincode,
    required bool isPrimary,
  }) {
    final m = <String, dynamic>{
      'address_1': address1,
      'address_2': address2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'is_primary': isPrimary,
    };
    final idVal = _jsonId(id);
    if (idVal != null) m['id'] = idVal;
    return m;
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
