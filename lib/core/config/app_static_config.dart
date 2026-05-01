/// When `true`, the app uses [StaticCrmQuotesApi] (no Zoho/Dio quote-list calls). Navigation still
/// follows splash → login → dashboard unless you change routes yourself.
///
/// Live CRM: `--dart-define=USE_STATIC_PREVIEW=false`
abstract final class AppStaticConfig {
  static const bool useStaticPreview = bool.fromEnvironment(
    'USE_STATIC_PREVIEW',
    defaultValue: true,
  );
}
