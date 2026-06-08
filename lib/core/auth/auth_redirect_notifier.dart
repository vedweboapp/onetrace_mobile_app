import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] to re-run [redirect] after login, logout, or token refresh.
final class AuthRedirectNotifier extends ChangeNotifier {
  void notifyAuthChanged() => notifyListeners();
}
