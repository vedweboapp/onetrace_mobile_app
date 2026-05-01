import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/app/app.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/shared_preferences_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localStorage = await SharedPreferencesStorage.create();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitDown,
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    ProviderScope(
      overrides: [localStorageProvider.overrideWith((ref) => localStorage)],
      child: const App(),
    ),
  );
}
