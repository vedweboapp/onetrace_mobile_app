import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';

/// Where to show the full main navigation (Sites, Groups, Products, Quotations, etc.).
enum NavMenuStyle {
  /// Classic [Drawer] from the leading menu and overflow.
  drawer,

  /// Same destinations in a modal bottom sheet (from leading + bottom “More”).
  bottomSheet,
}

/// Reads/writes [NavMenuStyle] to [LocalStorage].
abstract final class NavMenuStylePreference {
  const NavMenuStylePreference._();

  static NavMenuStyle read(LocalStorage storage) {
    final raw = storage.getString(LocalStorageKeys.appNavMenuStyle)?.trim();
    if (raw == 'bottom_sheet') return NavMenuStyle.bottomSheet;
    return NavMenuStyle.drawer;
  }

  static Future<void> write(LocalStorage storage, NavMenuStyle style) async {
    await storage.setString(
      LocalStorageKeys.appNavMenuStyle,
      switch (style) {
        NavMenuStyle.drawer => 'drawer',
        NavMenuStyle.bottomSheet => 'bottom_sheet',
      },
    );
  }
}
