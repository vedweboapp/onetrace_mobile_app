import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/storage/local_storage.dart';

/// Resolved from GetIt after [configureDependencies] in [main].
final localStorageProvider = Provider<LocalStorage>(
  (ref) => sl<LocalStorage>(),
);
