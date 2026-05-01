/// Zoho CRM / OAuth endpoints and credentials (prefer `--dart-define` in production).
class ZohoApiConfig {
  const ZohoApiConfig({
    this.refreshToken = const String.fromEnvironment(
      'ZOHO_REFRESH_TOKEN',
      defaultValue:
          '1000.4757c6a0b785fad2dff34eec6e3633e7.2ef506a08863260686b620593343389c',
    ),
    this.clientId = const String.fromEnvironment(
      'ZOHO_CLIENT_ID',
      defaultValue: '1000.MUREBA9JBJZRPYVYV4KGZJ1MITFXFS',
    ),
    this.clientSecret = const String.fromEnvironment(
      'ZOHO_CLIENT_SECRET',
      defaultValue: '1e9dd216af1532f19191b00bf6296a9cf11f06cedd',
    ),
    this.crmQuotesBaseUrl = 'https://www.zohoapis.eu/crm/v8/Quotes',
    this.tokenUrl = 'https://accounts.zoho.eu/oauth/v2/token',
    this.pageSize = 200,
  });

  final String refreshToken;
  final String clientId;
  final String clientSecret;
  final String crmQuotesBaseUrl;
  final String tokenUrl;
  final int pageSize;
}
