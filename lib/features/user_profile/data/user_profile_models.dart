import 'package:flutter/foundation.dart';

/// Nested `user_detail` payload returned by `/user-profile/`.
@immutable
class UserDetail {
  const UserDetail({
    required this.id,
    required this.uuid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.gender,
    required this.userImage,
    required this.inviteStatus,
    required this.invitationSentAt,
    required this.invitationExpired,
  });

  final String id;
  final String uuid;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String gender;
  final String userImage;
  final String inviteStatus;
  final String invitationSentAt;
  final bool invitationExpired;

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      id: _readString(json, const ['id']),
      uuid: _readString(json, const ['uuid']),
      firstName: _readString(json, const ['first_name', 'firstName']),
      lastName: _readString(json, const ['last_name', 'lastName']),
      email: _readString(json, const ['email', 'email_address']),
      phoneNumber: _readString(json, const [
        'phone_number',
        'phone',
        'mobile',
        'phoneNumber',
      ]),
      gender: _readString(json, const ['gender']),
      userImage: _readString(json, const ['user_image', 'image', 'avatar']),
      inviteStatus: _readString(json, const ['invite_status']),
      invitationSentAt: _readString(json, const ['invitation_sent_at']),
      invitationExpired: _readBool(json, const ['invitation_expired']),
    );
  }
}

/// Full record returned by `/user-profile/`.
///
/// The payload wraps a [UserDetail] under `user_detail`, plus profile-level
/// fields (role, address, date of birth, …) returned at the top level when
/// available.
@immutable
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.userDetail,
    required this.role,
    required this.dateOfBirth,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
  });

  final String id;
  final UserDetail userDetail;
  final String role;
  final String dateOfBirth;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String postalCode;

  String get firstName => userDetail.firstName;
  String get lastName => userDetail.lastName;
  String get email => userDetail.email;
  String get phoneNumber => userDetail.phoneNumber;
  String get gender => userDetail.gender;
  String get userImage => userDetail.userImage;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final detailRaw = json['user_detail'];
    final detailMap = detailRaw is Map
        ? Map<String, dynamic>.from(detailRaw)
        : <String, dynamic>{};
    return UserProfileModel(
      id: _readString(json, const ['id']),
      userDetail: UserDetail.fromJson(detailMap),
      role: _readString(json, const ['role', 'designation', 'job_title']),
      dateOfBirth: _readString(json, const [
        'date_of_birth',
        'dob',
        'birth_date',
      ]),
      addressLine1: _readString(json, const [
        'address_line_1',
        'address_line1',
        'address1',
        'address',
      ]),
      addressLine2: _readString(json, const [
        'address_line_2',
        'address_line2',
        'address2',
      ]),
      city: _readString(json, const ['city']),
      state: _readString(json, const ['state', 'province']),
      country: _readString(json, const ['country']),
      postalCode: _readString(json, const [
        'postal_code',
        'zip_code',
        'pincode',
        'zip',
      ]),
    );
  }
}

String _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') continue;
    return text;
  }
  return '';
}

bool _readBool(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final t = raw.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
  }
  return false;
}
