import 'dart:typed_data';

import 'package:red5/core/network/auth_api_client.dart';

/// Invite payload assembled from the invite form ([profilePhotoBytes] optional).
final class InviteUserPayload {
  const InviteUserPayload({
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.gender,
    required this.dateOfBirth,
    required this.phone,
    required this.email,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.zipCode,
    this.profilePhotoBytes,
  });

  final String firstName;
  final String lastName;
  final String role;
  final String gender;
  final String dateOfBirth;
  final String phone;
  final String email;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String zipCode;
  final Uint8List? profilePhotoBytes;

  /// Snake-cased fields matching the typical Django REST naming the backend
  /// expects. `profile_photo` is intentionally omitted: the photo is sent
  /// as a multipart file when present.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'first_name': firstName,
    'last_name': lastName,
    'role': role,
    'gender': gender,
    'date_of_birth': dateOfBirth,
    'phone': phone,
    'email': email,
    'address_line1': addressLine1,
    'address_line2': addressLine2,
    'city': city,
    'state': state,
    'zip_code': zipCode,
  };
}

/// Remote invite API — see [InviteUserApiService] for the live `POST /auth/invite-user/`
/// implementation, or [InviteUserServiceStub] for tests/offline runs.
abstract class InviteUserService {
  Future<void> invite(InviteUserPayload payload);
}

/// Calls `POST /auth/invite-user/` via [AuthApiClient]. Sends multipart when
/// [InviteUserPayload.profilePhotoBytes] is provided.
final class InviteUserApiService implements InviteUserService {
  InviteUserApiService(this._client);

  final AuthApiClient _client;

  @override
  Future<void> invite(InviteUserPayload payload) async {
    await _client.inviteUser(
      data: payload.toJson(),
      profilePhotoBytes: payload.profilePhotoBytes,
    );
  }
}

final class InviteUserServiceStub implements InviteUserService {
  @override
  Future<void> invite(InviteUserPayload payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
  }
}
