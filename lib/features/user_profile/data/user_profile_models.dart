import 'package:flutter/foundation.dart';

/// One row from `communications` on user profile GET/PUT.
@immutable
class UserCommunicationModel {
  const UserCommunicationModel({
    required this.id,
    required this.phone,
    required this.email,
    required this.isPrimary,
  });

  final String id;
  final String phone;
  final String email;
  final bool isPrimary;

  factory UserCommunicationModel.fromJson(Map<String, dynamic> json) {
    return UserCommunicationModel(
      id: _readString(json, const ['id']),
      phone: _readString(json, const ['phone', 'phone_number', 'mobile']),
      email: _readString(json, const ['email', 'email_address']),
      isPrimary: _readBool(json, const ['is_primary', 'isPrimary']),
    );
  }
}

/// One row from `addresses` on user profile GET/PUT.
@immutable
class UserAddressModel {
  const UserAddressModel({
    required this.id,
    required this.address1,
    required this.address2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.isPrimary,
  });

  final String id;
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String pincode;
  final bool isPrimary;

  factory UserAddressModel.fromJson(Map<String, dynamic> json) {
    return UserAddressModel(
      id: _readString(json, const ['id']),
      address1: _readString(json, const [
        'address_1',
        'address_line_1',
        'address_line1',
        'address1',
      ]),
      address2: _readString(json, const [
        'address_2',
        'address_line_2',
        'address_line2',
        'address2',
      ]),
      city: _readString(json, const ['city']),
      state: _readString(json, const ['state', 'province']),
      pincode: _readString(json, const [
        'pincode',
        'postal_code',
        'zip_code',
        'zip',
      ]),
      isPrimary: _readBool(json, const ['is_primary', 'isPrimary']),
    );
  }
}

/// Nested `user_detail` or top-level user fields from `/user-profile/`.
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

/// Full record from `GET/PUT/PATCH /user-profile/` (UserWrite-style + legacy).
@immutable
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.userDetail,
    required this.role,
    required this.roleId,
    required this.dateOfBirth,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.communications,
    required this.addresses,
  });

  final String id;
  final UserDetail userDetail;
  /// Display label (e.g. nested `role_name`); may be empty when only `roleId` is set.
  final String role;
  /// FK to `/api/v1/role/` when API returns int or nested role object.
  final String roleId;
  final String dateOfBirth;
  /// Legacy flat address when API has no `addresses[]`.
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String country;
  final String postalCode;

  /// `communications` from API (phones/emails per row).
  final List<UserCommunicationModel> communications;

  /// `addresses` from API (`address_1`, `pincode`, …).
  final List<UserAddressModel> addresses;

  String get firstName => userDetail.firstName;
  String get lastName => userDetail.lastName;
  String get email => userDetail.email;
  String get phoneNumber => userDetail.phoneNumber;
  String get gender => userDetail.gender;
  String get userImage => userDetail.userImage;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final id = _readString(json, const ['id']);

    final detailRaw = json['user_detail'];
    final detailMap = detailRaw is Map
        ? Map<String, dynamic>.from(
            detailRaw.map((k, v) => MapEntry(k.toString(), v)),
          )
        : <String, dynamic>{};

    final merged = Map<String, dynamic>.from(
      json.map((k, v) => MapEntry(k.toString(), v)),
    );
    for (final e in detailMap.entries) {
      final v = e.value;
      if (v == null) continue;
      final existing = merged[e.key];
      if (existing == null ||
          (existing is String && existing.trim().isEmpty)) {
        merged[e.key] = v;
      }
    }

    final communications = _parseCommunications(json);
    final addresses = _parseAddresses(json);

    final detail = UserDetail.fromJson(merged);

    final parsedRole = _parseRoleFields(json, merged);

    return UserProfileModel(
      id: id.isNotEmpty ? id : detail.id,
      userDetail: detail,
      role: parsedRole.displayName,
      roleId: parsedRole.roleId,
      dateOfBirth: _readString(json, const [
        'date_of_birth',
        'dob',
        'birth_date',
      ]),
      addressLine1: _readString(merged, const [
        'address_line_1',
        'address_line1',
        'address1',
        'address',
      ]),
      addressLine2: _readString(merged, const [
        'address_line_2',
        'address_line2',
        'address2',
      ]),
      city: _readString(merged, const ['city']),
      state: _readString(merged, const ['state', 'province']),
      country: _readString(merged, const ['country']),
      postalCode: _readString(merged, const [
        'postal_code',
        'zip_code',
        'pincode',
        'zip',
      ]),
      communications: communications,
      addresses: addresses,
    );
  }

  /// Parses `role` as int id, nested map (`role_name`), or legacy string label.
  static ({String roleId, String displayName}) _parseRoleFields(
    Map<String, dynamic> json,
    Map<String, dynamic> merged,
  ) {
    for (final map in [json, merged]) {
      final fromNested = _readString(map, const [
        'role_name',
        'roleName',
      ]);
      final nested = map['role_details'] ?? map['role_detail'] ?? map['role_obj'];
      if (nested is Map) {
        final nm = Map<String, dynamic>.from(
          nested.map((k, v) => MapEntry(k.toString(), v)),
        );
        final id = _readString(nm, const ['id']);
        final name = _readString(nm, const ['role_name', 'name']);
        if (id.isNotEmpty || name.isNotEmpty) {
          return (roleId: id, displayName: name.isNotEmpty ? name : fromNested);
        }
      }

      final raw = map['role'] ?? map['role_id'];
      if (raw is int) {
        return (roleId: raw.toString(), displayName: fromNested);
      }
      if (raw is num) {
        return (roleId: raw.toInt().toString(), displayName: fromNested);
      }
      if (raw is String) {
        final t = raw.trim();
        if (t.isEmpty || t == 'null') continue;
        final asInt = int.tryParse(t);
        if (asInt != null) {
          return (roleId: t, displayName: fromNested);
        }
        return (roleId: '', displayName: t);
      }
      if (raw is Map) {
        final rm = Map<String, dynamic>.from(
          raw.map((k, v) => MapEntry(k.toString(), v)),
        );
        final id = _readString(rm, const ['id']);
        final name = _readString(rm, const ['role_name', 'name']);
        return (roleId: id, displayName: name);
      }
    }
    return (
      roleId: '',
      displayName: _readString(json, const [
        'designation',
        'job_title',
        'role_name',
      ]),
    );
  }

  static List<UserCommunicationModel> _parseCommunications(
    Map<String, dynamic> json,
  ) {
    final raw = json['communications'];
    if (raw is! List) return const [];
    final out = <UserCommunicationModel>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(UserCommunicationModel.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  static List<UserAddressModel> _parseAddresses(Map<String, dynamic> json) {
    final raw = json['addresses'];
    if (raw is! List) return const [];
    final out = <UserAddressModel>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(UserAddressModel.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
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
