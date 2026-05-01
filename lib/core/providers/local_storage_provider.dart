import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/storage/local_storage.dart';

/// Injected from [main] via [ProviderScope.overrides].
final localStorageProvider = Provider<LocalStorage>((ref) {
  throw StateError(
    'localStorageProvider is not initialized. '
    'Call SharedPreferencesStorage.create() in main() and override this provider.',
  );
});
