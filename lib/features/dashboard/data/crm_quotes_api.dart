import 'package:red5/features/dashboard/data/quote_list_page_result.dart';

/// Remote quotes source (CRM). Implementations may call Zoho, a custom backend, etc.
abstract class CrmQuotesApi {
  Future<QuoteListPageResult> fetchQuotesPage(int page);

  /// JSON map shaped for dashboard `_QuotePayload.fromJson` / UI.
  Future<Map<String, dynamic>> fetchQuoteAppPayload(String quoteId);
}
