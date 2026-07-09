import 'package:red5/core/config/google_api_config.dart';

/// Google Maps SDK key (shared with Places / Geocoding on the same key).
abstract final class GoogleMapsConfig {
  GoogleMapsConfig._();

  static String get apiKey => GoogleApiConfig.apiKey;

  static bool get isConfigured => GoogleApiConfig.isConfigured;
}
