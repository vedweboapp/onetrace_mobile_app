/// Shared Google Maps / Places / Geocoding API key.
///
/// Operative maps use the **Maps JavaScript API** in a WebView (same as the
/// website). Prefer passing the key via `--dart-define-from-file=dart_defines.json`
/// (launch config **red5 (with Google Maps key)**). A project fallback is used
/// when dart-define is missing so IDE "Run" still shows maps.
abstract final class GoogleApiConfig {
  GoogleApiConfig._();

  static const language = 'en-GB';

  /// Same key as website Maps JS / local `dart_defines.json`.
  static const _fallbackKey = 'AIzaSyAAgbQXtNsrzIjldTTrrH8beWx7zO-HocI';

  /// True when a non-empty key is available.
  static bool get isConfigured => apiKey.isNotEmpty;

  /// API key for Maps JavaScript (WebView), Places, and Geocoding REST calls.
  static String get apiKey {
    const mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (mapsKey.isNotEmpty) return mapsKey;

    // Backward compatibility with older build scripts.
    const placesKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
    if (placesKey.isNotEmpty) return placesKey;

    return _fallbackKey;
  }
}
