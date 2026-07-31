/// Shared Google Maps SDK, Places Autocomplete, and Geocoding API key.
///
/// Configure **three** local files (copy from the `*.example` templates):
/// - `dart_defines.json` — Dart REST calls (geocoding, places)
/// - `android/secrets.properties` — native Android map in AndroidManifest
/// - `ios/Runner/Secrets.xcconfig` — native iOS map in Info.plist
///
/// In Google Cloud Console, enable billing and these APIs for the same project
/// as the key (a blank map with only the Google logo means Maps SDK is off):
/// - Maps SDK for Android
/// - Maps SDK for iOS
/// - Places API
/// - Geocoding API
///
/// If the key uses Android app restrictions, allow package `com.example.red5`
/// plus your debug/release SHA-1 fingerprints.
///
/// Run with:
/// `flutter run --dart-define-from-file=dart_defines.json`
///
/// Or use the VS Code/Cursor launch config **red5 (with Google Maps key)**.
abstract final class GoogleApiConfig {
  GoogleApiConfig._();

  static const language = 'en-GB';

  /// True when a non-empty key was supplied via `--dart-define`.
  static bool get isConfigured => apiKey.isNotEmpty;

  /// API key for Maps SDK (native), Places, and Geocoding REST calls.
  static String get apiKey {
    const mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (mapsKey.isNotEmpty) return mapsKey;

    // Backward compatibility with older build scripts.
    const placesKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
    if (placesKey.isNotEmpty) return placesKey;

    return '';
  }
}
