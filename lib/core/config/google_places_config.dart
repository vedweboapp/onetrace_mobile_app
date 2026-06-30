/// Google Places API configuration (Autocomplete + Place Details).
abstract final class GooglePlacesConfig {
  GooglePlacesConfig._();

  /// Default key used by the web purchase-order form.
  /// Override at build time with `--dart-define=GOOGLE_PLACES_API_KEY=...`.
  static const defaultApiKey = 'AIzaSyAAgbQXtNsrzIjldTTrrH8beWx7zO-HocI';

  static const language = 'en-GB';

  static String get apiKey {
    const fromEnv = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return defaultApiKey;
  }
}
