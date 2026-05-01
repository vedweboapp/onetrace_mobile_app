import 'dart:convert';

import 'package:red5/core/network/app_http_client.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api.dart';
import 'package:red5/features/dashboard/data/quote_list_page_result.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/data/zoho_api_config.dart';
import 'package:red5/features/dashboard/data/zoho_quote_record_mapper.dart';

/// Zoho CRM Quotes + OAuth refresh using [AppHttpClient] (Dio).
class ZohoCrmQuotesApi implements CrmQuotesApi {
  ZohoCrmQuotesApi({
    required AppHttpClient http,
    required ZohoApiConfig config,
  })  : _http = http,
        _config = config;

  final AppHttpClient _http;
  final ZohoApiConfig _config;

  String? _accessToken;
  DateTime? _accessTokenExpiryUtc;

  Future<String> _ensureAccessToken() async {
    final now = DateTime.now().toUtc();
    final token = _accessToken;
    final expiry = _accessTokenExpiryUtc;
    if (token != null &&
        token.trim().isNotEmpty &&
        expiry != null &&
        now.isBefore(expiry.subtract(const Duration(seconds: 30)))) {
      return token;
    }

    final formBody = Uri(
      queryParameters: {
        'refresh_token': _config.refreshToken,
        'client_id': _config.clientId,
        'client_secret': _config.clientSecret,
        'grant_type': 'refresh_token',
      },
    ).query;

    final res = await _http.postFormUrlEncoded(_config.tokenUrl, body: formBody);
    if (!res.isSuccess) {
      throw Exception('Token API returned ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid token response');
    }

    final accessToken = decoded['access_token'];
    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw Exception('Missing access_token in token response');
    }

    final expiresInRaw = decoded['expires_in'];
    var expiresInSeconds = 3600;
    if (expiresInRaw is int) {
      expiresInSeconds = expiresInRaw;
    } else if (expiresInRaw is String) {
      expiresInSeconds = int.tryParse(expiresInRaw) ?? 3600;
    }

    _accessToken = accessToken.trim();
    _accessTokenExpiryUtc = now.add(Duration(seconds: expiresInSeconds));
    return _accessToken!;
  }

  Uri _listUriForPage(int page) {
    return Uri.parse(_config.crmQuotesBaseUrl).replace(
      queryParameters: {
        'fields': 'id,Quote_Number,Subject',
        'page': '$page',
        'per_page': '${_config.pageSize}',
      },
    );
  }

  @override
  Future<QuoteListPageResult> fetchQuotesPage(int page) async {
    final token = await _ensureAccessToken();
    final uri = _listUriForPage(page);
    final res = await _http.get(
      uri.toString(),
      headers: {'Authorization': 'Zoho-oauthtoken $token'},
    );
    final body = res.body.trim();
    if (!res.isSuccess) {
      throw Exception('API returned ${res.statusCode}');
    }

    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) {
      throw Exception('Invalid API response');
    }

    final list = ZohoQuoteRecordMapper.extractQuoteSummaries(root);
    final info = QuoteListInfo.fromJson(root['info']);
    final totalPages =
        ((info.count + _config.pageSize - 1) ~/ _config.pageSize).clamp(1, 999999);

    return QuoteListPageResult(
      summaries: list,
      page: page,
      totalPages: totalPages,
      hasMoreRecords: info.moreRecords,
    );
  }

  @override
  Future<Map<String, dynamic>> fetchQuoteAppPayload(String quoteId) async {
    final token = await _ensureAccessToken();
    final url = '${_config.crmQuotesBaseUrl}/$quoteId';
    final res = await _http.get(
      url,
      headers: {'Authorization': 'Zoho-oauthtoken $token'},
    );
    final body = res.body.trim();
    if (!res.isSuccess) {
      throw Exception('Quote detail API returned ${res.statusCode}');
    }

    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) {
      throw Exception('Invalid quote detail response');
    }

    final output =
        ZohoQuoteRecordMapper.extractPayloadFromCrmResponse(root) ??
        ZohoQuoteRecordMapper.extractPayloadMap(root);
    if (output == null) {
      throw Exception('Quote detail payload missing');
    }
    return output;
  }
}
