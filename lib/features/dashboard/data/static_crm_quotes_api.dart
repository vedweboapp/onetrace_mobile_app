import 'package:red5/features/dashboard/data/crm_quotes_api.dart';
import 'package:red5/features/dashboard/data/quote_list_page_result.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';

/// Fixed quotes + payloads for UI preview / design (no network).
class StaticCrmQuotesApi implements CrmQuotesApi {
  const StaticCrmQuotesApi();

  static const List<QuoteSummary> _summaries = [
    QuoteSummary(
      id: 'static-quote-1',
      quoteName: 'Demo residence — Oak block',
      quoteNumber: 'Q-24001',
      clientName: 'Apex Structural Group',
      projectName: 'Oak Street Tower',
      contactPhone: '+1 (555) 124-8902',
    ),
    QuoteSummary(
      id: 'static-quote-2',
      quoteName: 'Sample tower — River view',
      quoteNumber: 'Q-24002',
      clientName: 'Riverview Developments',
      projectName: 'Downtown Phase 2',
      contactPhone: '+1 (555) 200-4410',
    ),
    QuoteSummary(
      id: 'static-quote-3',
      quoteName: 'Static preview quote',
      quoteNumber: 'Q-24003',
      clientName: 'Northwind LLC',
      projectName: 'Warehouse retrofit',
      contactPhone: '+1 (555) 981-0001',
    ),
  ];

  @override
  Future<QuoteListPageResult> fetchQuotesPage(int page) async {
    return QuoteListPageResult(
      summaries: _summaries,
      page: page,
      totalPages: 1,
      hasMoreRecords: false,
    );
  }

  @override
  Future<Map<String, dynamic>> fetchQuoteAppPayload(String quoteId) async {
    final isSecond = quoteId == 'static-quote-2';
    return {
      'quote': {
        'quote_name': isSecond ? 'Sample tower — River view' : 'Demo residence — Oak block',
        'quote_number': isSecond ? 'Q-24002' : 'Q-24001',
        'quote_stage': 'Draft',
        'valid_till': '2026-12-31',
        'property': 'Riverside development',
        'door_survey': 'Scheduled',
        'deal_name': 'Acme Homes Ltd',
        'wardrive_pdf_link': '',
        'workdrive_pdf_download': '',
        'contact_name': 'Jane Demo',
        'created_by': 'Static preview',
        'layout': 'Standard quote',
      },
      'products': [
        {
          'product_name': 'Aluminium window — Type A',
          'quantity': 4,
          'total': 3200.0,
          'levels': 'Level 2',
          'plots': 'Plot 12A',
          'x_coordinate': 22.0,
          'y_coordinate': 35.0,
        },
        {
          'product_name': 'Composite door — Main',
          'quantity': 1,
          'total': 1899.0,
          'levels': 'Ground',
          'plots': 'Plot 12A',
          'x_coordinate': 55.0,
          'y_coordinate': 40.0,
        },
      ],
      'composite_groups': [
        {
          'title': 'Static bundle — hardware',
          'items': [
            {'name': 'Hinge set', 'quantity': 2, 'total': 48.0, 'sku': 'HW-01'},
            {'name': 'Handle pack', 'quantity': 1, 'total': 65.0, 'sku': 'HW-02'},
          ],
        },
      ],
    };
  }
}
