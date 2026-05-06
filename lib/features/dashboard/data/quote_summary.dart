class QuoteSummary {
  const QuoteSummary({
    required this.id,
    required this.quoteName,
    required this.quoteNumber,
    this.clientName,
    this.description,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String quoteName;
  final String quoteNumber;
  final String? clientName;
  final String? description;
  final String? startDate;
  final String? endDate;

  static QuoteSummary? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final subject = (json['Subject'] as String?)?.trim();
    final quoteNo = (json['Quote_Number'] as String?)?.trim();
    return QuoteSummary(
      id: id,
      quoteName: (subject == null || subject.isEmpty) ? 'Untitled Quote' : subject,
      quoteNumber: (quoteNo == null || quoteNo.isEmpty) ? '—' : quoteNo,
      clientName: (json['client_name'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      startDate: (json['start_date'] as String?)?.trim(),
      endDate: (json['end_date'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'quoteName': quoteName,
    'quoteNumber': quoteNumber,
    if (clientName != null) 'clientName': clientName,
    if (description != null) 'description': description,
    if (startDate != null) 'startDate': startDate,
    if (endDate != null) 'endDate': endDate,
  };

  static QuoteSummary? fromMap(Map<String, dynamic> map) {
    final id = (map['id'] as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final name = (map['quoteName'] as String?)?.trim();
    final number = (map['quoteNumber'] as String?)?.trim();
    return QuoteSummary(
      id: id,
      quoteName: (name == null || name.isEmpty) ? 'Untitled Quote' : name,
      quoteNumber: (number == null || number.isEmpty) ? '—' : number,
      clientName: (map['clientName'] as String?)?.trim(),
      description: (map['description'] as String?)?.trim(),
      startDate: (map['startDate'] as String?)?.trim(),
      endDate: (map['endDate'] as String?)?.trim(),
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
