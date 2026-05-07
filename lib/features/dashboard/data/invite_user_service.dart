import 'dart:typed_data';

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
}

/// Remote invite API — replace [InviteUserServiceStub] with a Dio-backed impl when wired.
abstract class InviteUserService {
  Future<void> invite(InviteUserPayload payload);
}

final class InviteUserServiceStub implements InviteUserService {
  @override
  Future<void> invite(InviteUserPayload payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    // Stub: integrate POST /invite or equivalent when backend is ready.
  }
}
