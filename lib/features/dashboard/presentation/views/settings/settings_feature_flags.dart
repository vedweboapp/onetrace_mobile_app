/// Temporary toggles for settings navigation (code stays; UI can be hidden or disabled).
class SettingsFeatureFlags {
  SettingsFeatureFlags._();

  /// Meta Data (pin status, job status, project type, tags, modules & fields).
  /// When `false`, entry points stay visible but are not tappable; screens and
  /// routes remain in the app unchanged.
  static const bool metadataEnabled = false;

  /// Keep Meta Data visible in settings menus (use [metadataEnabled] for taps).
  static const bool showMetaData = true;

  /// Module & field metadata screens — tied to [metadataEnabled].
  static bool get showModuleAndField => metadataEnabled;
}
