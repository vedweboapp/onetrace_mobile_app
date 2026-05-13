import 'package:flutter/foundation.dart';
import 'package:flutter_keyboard_visibility_linux/flutter_keyboard_visibility_linux.dart';
import 'package:flutter_keyboard_visibility_macos/flutter_keyboard_visibility_macos.dart';
import 'package:flutter_keyboard_visibility_windows/flutter_keyboard_visibility_windows.dart';

/// [flutter_quill] depends on [flutter_keyboard_visibility_temp_fork], which
/// defaults to a [MethodChannel] / EventChannel named `flutter_keyboard_visibility`.
/// On Android/iOS the native plugin registers that channel; on desktop the
/// federated implementations swap in a Dart [Stream] (no native channel) via
/// [FlutterKeyboardVisibilityPlatform.instance], but that swap does not always
/// run before Quill subscribes, causing [MissingPluginException].
///
/// Call once after [WidgetsFlutterBinding.ensureInitialized] from [main].
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
