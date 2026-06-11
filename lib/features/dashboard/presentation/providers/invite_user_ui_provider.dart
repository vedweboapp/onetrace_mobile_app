import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
final class InviteUserUiState {
  const InviteUserUiState({this.submitting = false});

  final bool submitting;
}

final inviteUserUiProvider =
    StateNotifierProvider.autoDispose<InviteUserUiNotifier, InviteUserUiState>(
  (_) => InviteUserUiNotifier(),
);

final class InviteUserUiNotifier extends StateNotifier<InviteUserUiState> {
  InviteUserUiNotifier() : super(const InviteUserUiState());

  void setSubmitting(bool value) => state = InviteUserUiState(submitting: value);
}
