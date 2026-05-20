import 'package:flutter/foundation.dart';
import 'package:flutter_keyboard_visibility_linux/flutter_keyboard_visibility_linux.dart';
import 'package:flutter_keyboard_visibility_macos/flutter_keyboard_visibility_macos.dart';
import 'package:flutter_keyboard_visibility_windows/flutter_keyboard_visibility_windows.dart';

/// Call once after [WidgetsFlutterBinding.ensureInitialized] from [main].
///
///
void registerDesktopKeyboardVisibilityShims() {
  if (kIsWeb) return;
  final p = defaultTargetPlatform;
  if (p == TargetPlatform.windows) {
    FlutterKeyboardVisibilityPluginWindows.registerWith();
  } else if (p == TargetPlatform.linux) {
    FlutterKeyboardVisibilityPluginLinux.registerWith();
  } else if (p == TargetPlatform.macOS) {
    FlutterKeyboardVisibilityPluginMacos.registerWith();
  }
}
