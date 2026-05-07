import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
final class InviteUserUiState {
  const InviteUserUiState({
    this.profilePhotoBytes,
    this.submitting = false,
  });

  final Uint8List? profilePhotoBytes;
  final bool submitting;
}

final inviteUserUiProvider =
    StateNotifierProvider.autoDispose<InviteUserUiNotifier, InviteUserUiState>(
  (_) => InviteUserUiNotifier(),
);

final class InviteUserUiNotifier extends StateNotifier<InviteUserUiState> {
  InviteUserUiNotifier() : super(const InviteUserUiState());

  void setProfilePhotoBytes(Uint8List? bytes) => state = InviteUserUiState(
        profilePhotoBytes: bytes,
        submitting: state.submitting,
      );

  void clearProfilePhoto() => setProfilePhotoBytes(null);

  void setSubmitting(bool value) => state = InviteUserUiState(
        profilePhotoBytes: state.profilePhotoBytes,
        submitting: value,
      );
}
