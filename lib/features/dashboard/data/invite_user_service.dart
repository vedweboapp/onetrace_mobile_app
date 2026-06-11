import 'package:red5/core/network/auth_api_client.dart';

/// Invite payload assembled from the invite form — matches `POST /auth/invite-user/`.
final class InviteUserPayload {
  const InviteUserPayload({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.gender,
    required this.role,
    required this.address1,
    required this.address2,
    required this.country,
    required this.state,
    required this.city,
    required this.pincode,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String gender;
  final int role;
  final String address1;
  final String address2;
  final String country;
  final String state;
  final String city;
  final String pincode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'gender': gender,
        'role': role,
        'address1': address1,
        'address2': address2,
        'country': country,
        'state': state,
        'city': city,
        'pincode': pincode,
      };
}

/// Remote invite API — see [InviteUserApiService] for the live `POST /auth/invite-user/`
/// implementation, or [InviteUserServiceStub] for tests/offline runs.
abstract class InviteUserService {
  Future<void> invite(InviteUserPayload payload);
}

/// Calls `POST /auth/invite-user/` via [AuthApiClient].
final class InviteUserApiService implements InviteUserService {
  InviteUserApiService(this._client);

  final AuthApiClient _client;

  @override
  Future<void> invite(InviteUserPayload payload) async {
    await _client.inviteUser(data: payload.toJson());
  }
}

final class InviteUserServiceStub implements InviteUserService {
  @override
  Future<void> invite(InviteUserPayload payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
  }
}
