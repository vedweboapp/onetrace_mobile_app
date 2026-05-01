class QuoteSummary {
  const QuoteSummary({
    required this.id,
    required this.quoteName,
    required this.quoteNumber,
  });

  final String id;
  final String quoteName;
  final String quoteNumber;

  static QuoteSummary? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final subject = (json['Subject'] as String?)?.trim();
    final quoteNo = (json['Quote_Number'] as String?)?.trim();
    return QuoteSummary(
      id: id,
      quoteName: (subject == null || subject.isEmpty) ? 'Untitled Quote' : subject,
      quoteNumber: (quoteNo == null || quoteNo.isEmpty) ? '—' : quoteNo,
    );
  }
}

class QuoteListInfo {
  const QuoteListInfo({required this.count, required this.moreRecords});

  final int count;
  final bool moreRecords;

  static QuoteListInfo fromJson(dynamic raw) {
    if (raw is! Map) return const QuoteListInfo(count: 0, moreRecords: false);
    final countRaw = raw['count'];
    final moreRaw = raw['more_records'];
    final count = countRaw is int ? countRaw : int.tryParse('$countRaw') ?? 0;
    final more = moreRaw is bool ? moreRaw : '$moreRaw'.toLowerCase() == 'true';
    return QuoteListInfo(count: count, moreRecords: more);
  }
}
