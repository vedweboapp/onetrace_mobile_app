import 'package:red5/features/dashboard/data/quote_summary.dart';

class QuoteListPageResult {
  const QuoteListPageResult({
    required this.summaries,
    required this.page,
    required this.totalPages,
    required this.hasMoreRecords,
  });

  final List<QuoteSummary> summaries;
  final int page;
  final int totalPages;
  final bool hasMoreRecords;
}
