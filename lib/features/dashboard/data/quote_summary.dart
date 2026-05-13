class QuoteSummary {
  const QuoteSummary({
    required this.id,
    required this.quoteName,
    required this.quoteNumber,
    this.clientName,
    this.projectName,
    this.contactPhone,
    this.description,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String quoteName;
  final String quoteNumber;
  final String? clientName;
  /// Site / deal / property label for list rows (optional).
  final String? projectName;
  final String? contactPhone;
  final String? description;
  final String? startDate;
  final String? endDate;

  static String? _readId(Map<String, dynamic> json) {
    final raw = json['id'];
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static QuoteSummary? fromJson(Map<String, dynamic> json) {
    final id = _readId(json);
    if (id == null) return null;
    final subject = (json['Subject'] as String?)?.trim();
    final quoteNo = (json['Quote_Number'] as String?)?.trim();
    return QuoteSummary(
      id: id,
      quoteName: (subject == null || subject.isEmpty) ? 'Untitled Quote' : subject,
      quoteNumber: (quoteNo == null || quoteNo.isEmpty) ? '—' : quoteNo,
      clientName: (json['client_name'] as String?)?.trim(),
      projectName: (json['project_name'] as String?)?.trim(),
      contactPhone: (json['contact_phone'] as String?)?.trim(),
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
    if (projectName != null) 'projectName': projectName,
    if (contactPhone != null) 'contactPhone': contactPhone,
    if (description != null) 'description': description,
    if (startDate != null) 'startDate': startDate,
    if (endDate != null) 'endDate': endDate,
  };

  static QuoteSummary? fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final id = rawId == null ? '' : rawId.toString().trim();
    if (id.isEmpty) return null;
    final name = (map['quoteName'] as String?)?.trim();
    final number = (map['quoteNumber'] as String?)?.trim();
    return QuoteSummary(
      id: id,
      quoteName: (name == null || name.isEmpty) ? 'Untitled Quote' : name,
      quoteNumber: (number == null || number.isEmpty) ? '—' : number,
      clientName: (map['clientName'] as String?)?.trim(),
      projectName: (map['projectName'] as String?)?.trim(),
      contactPhone: (map['contactPhone'] as String?)?.trim(),
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
