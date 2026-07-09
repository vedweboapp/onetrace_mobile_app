import 'package:red5/core/config/google_api_config.dart';

/// Google Places API configuration (Autocomplete + Place Details).
abstract final class GooglePlacesConfig {
  GooglePlacesConfig._();

  static String get apiKey => GoogleApiConfig.apiKey;

  static String get language => GoogleApiConfig.language;

  static bool get isConfigured => GoogleApiConfig.isConfigured;
}
