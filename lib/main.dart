import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/app/app.dart';
import 'package:red5/core/bootstrap/register_desktop_keyboard_visibility.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/storage/shared_preferences_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerDesktopKeyboardVisibilityShims();
  final localStorage = await SharedPreferencesStorage.create();
  await configureDependencies(localStorage: localStorage);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitDown,
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: App()));
}
