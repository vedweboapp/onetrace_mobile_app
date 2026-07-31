import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isEmpty || text == 'null') continue;
    return text;
  }
  return fallback;
}

/// One row from `GET /api/v1/quotations/`.
@immutable
class QuotationListItem {
  const QuotationListItem({
    required this.id,
    required this.quoteName,
    required this.quoteNumber,
    this.quotationSerialNumber,
    this.clientName,
    this.projectName,
    this.siteName,
    this.contactPhone,
    this.description,
  });

  final String id;
  final String quoteName;
  final String quoteNumber;

  /// Preferred list heading when present (e.g. `QUOTE062`).
  final String? quotationSerialNumber;
  final String? clientName;
  final String? projectName;
  final String? siteName;
  final String? contactPhone;
  final String? description;

  /// Title shown in quotation lists — serial number first, then quote name.
  String get listTitle {
    final serial = quotationSerialNumber?.trim() ?? '';
    if (serial.isNotEmpty) return serial;
    final number = quoteNumber.trim();
    if (number.isNotEmpty && number != '—') return number;
    return quoteName;
  }

  factory QuotationListItem.fromJson(Map<String, dynamic> json) {
    var id = _readString(json, const ['id', 'ID', 'quotation_id']);
    if (id.isEmpty) {
      id = _readString(json, const ['uuid', 'pk', 'reference']);
    }
    final projectNameStr = _emptyToNull(() {
      final n = _readNestedLabel(
        json,
        const ['project', 'deal'],
        const ['name', 'project_name', 'title'],
      );
      if (n.isNotEmpty) return n;
      return _readString(json, const ['project_name', 'site_name', 'property']);
    }());
    var quoteName = _readString(json, const [
      'quote_name',
      'name',
      'title',
      'Subject',
      'subject',
    ]);
    if (quoteName.isEmpty) {
      quoteName = projectNameStr?.trim() ?? '';
    }
    if (quoteName.isEmpty && id.isNotEmpty) {
      quoteName = 'Quotation #$id';
    }
    if (quoteName.isEmpty) {
      quoteName = 'Untitled';
    }
    final serial = _emptyToNull(
      _readString(json, const [
        'quotation_serial_number',
        'quote_serial_number',
        'serial_number',
      ]),
    );
    final topSite = _emptyToNull(
      _readNestedLabel(json, const ['site'], const ['site_name', 'name']),
    );
    final siteFromList = _firstSitesArrayName(json);
    final siteFromProject = _firstProjectSiteName(json);
    return QuotationListItem(
      id: id.isEmpty ? '—' : id,
      quoteName: quoteName,
      quoteNumber: _readString(json, const [
        'quotation_serial_number',
        'order_number',
        'quote_number',
        'number',
        'reference',
        'Quote_Number',
      ], fallback: '—'),
      quotationSerialNumber: serial,
      clientName: _emptyToNull(() {
        final n = _readNestedLabel(
          json,
          const ['client', 'customer'],
          const ['name', 'client_name', 'title'],
        );
        if (n.isNotEmpty) return n;
        return _readString(json, const ['client_name', 'customer_name']);
      }()),
      projectName: projectNameStr,
      siteName: topSite ?? siteFromList ?? siteFromProject,
      contactPhone: _readListContactPhone(json),
      description: _emptyToNull(
        _readString(json, const ['description', 'details']),
      ),
    );
  }
}

String? _emptyToNull(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

Map<String, dynamic>? _asStringKeyMap(dynamic raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return null;
}

/// Phone from nested contact objects (`primary_customer_contact`, etc.) or flat keys.
String? _readListContactPhone(Map<String, dynamic> json) {
  for (final key in const [
    'primary_customer_contact',
    'additional_customer_contact',
  ]) {
    final raw = json[key];
    if (raw is List && raw.isNotEmpty) {
      for (final entry in raw) {
        final m = _asStringKeyMap(entry);
        if (m == null) continue;
        final phone = _readString(m, const ['phone', 'mobile', 'tel']);
        if (phone.isNotEmpty) return phone;
      }
      continue;
    }
    final m = _asStringKeyMap(raw);
    if (m == null) continue;
    final phone = _readString(m, const ['phone', 'mobile', 'tel']);
    if (phone.isNotEmpty) return phone;
  }
  final customer = _asStringKeyMap(json['customer']);
  if (customer != null) {
    final phone = _readString(customer, const ['phone', 'mobile']);
    if (phone.isNotEmpty) return phone;
  }
  return _emptyToNull(
    _readString(json, const ['contact_phone', 'phone', 'mobile']),
  );
}

String? _firstSitesArrayName(Map<String, dynamic> json) {
  final sites = json['sites'];
  if (sites is! List || sites.isEmpty) return null;
  final first = _asStringKeyMap(sites.first);
  if (first == null) return null;
  return _emptyToNull(_readString(first, const ['site_name', 'name']));
}

String? _firstProjectSiteName(Map<String, dynamic> json) {
  final project = _asStringKeyMap(json['project']);
  if (project == null) return null;
  final sites = project['sites'];
  if (sites is! List || sites.isEmpty) return null;
  final first = _asStringKeyMap(sites.first);
  if (first == null) return null;
  return _emptyToNull(_readString(first, const ['site_name', 'name']));
}

String _displayContactObject(dynamic raw) {
  final m = _asStringKeyMap(raw);
  if (m == null) return '';
  final name = _readString(m, const ['name', 'title']);
  final phone = _readString(m, const ['phone', 'mobile']);
  final email = _readString(m, const ['email']);
  final parts = <String>[];
  if (name.isNotEmpty) parts.add(name);
  if (phone.isNotEmpty) parts.add(phone);
  if (email.isNotEmpty && email != name) parts.add(email);
  return parts.join(' · ');
}

String _formatUserLike(dynamic raw) {
  final m = _asStringKeyMap(raw);
  if (m == null) return '';
  final username = _readString(m, const ['username', 'name']);
  final email = _readString(m, const ['email']);
  if (username.isNotEmpty && email.isNotEmpty && username != email) {
    return '$username ($email)';
  }
  return username.isNotEmpty ? username : email;
}

String _formatTechniciansField(Map<String, dynamic> json) {
  final direct = json['technician'];
  if (direct is List && direct.isNotEmpty) {
    final labels = direct
        .map(_formatUserLike)
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (labels.isNotEmpty) return labels.join(', ');
  }
  final ids = json['technicians'];
  if (ids is List && ids.isNotEmpty) {
    return ids.map((e) => e.toString().trim()).join(', ');
  }
  return '';
}

String _formatTagsField(Map<String, dynamic> json) {
  final raw = json['tags'];
  if (raw is List && raw.isNotEmpty) {
    return raw.map((e) => e.toString().trim()).join(', ');
  }
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  return '';
}

/// Display chip for quotation tags (Overview UI).
@immutable
class QuotationTagChip {
  const QuotationTagChip({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;
}

List<QuotationTagChip> _parseTagChips(Map<String, dynamic> json) {
  final raw = json['tags'];
  if (raw is! List || raw.isEmpty) return const [];
  final out = <QuotationTagChip>[];
  for (final e in raw) {
    if (e is Map) {
      final m = Map<String, dynamic>.from(
        e.map((k, v) => MapEntry(k.toString(), v)),
      );
      final name = _readString(m, const [
        'name',
        'label',
        'title',
        'username',
        'full_name',
      ]);
      final avatar = _readString(m, const [
        'avatar',
        'avatar_url',
        'photo',
        'image',
        'profile_image',
      ]);
      if (name.isEmpty) continue;
      out.add(
        QuotationTagChip(name: name, avatarUrl: avatar.isEmpty ? null : avatar),
      );
    } else {
      final s = e.toString().trim();
      if (s.isNotEmpty && s != 'null') {
        out.add(QuotationTagChip(name: s));
      }
    }
  }
  return out;
}

String _readNestedLabel(
  Map<String, dynamic> json,
  List<String> objectKeys,
  List<String> nameKeys,
) {
  for (final ok in objectKeys) {
    final raw = json[ok];
    if (raw is Map) {
      final m = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      final s = _readString(m, nameKeys);
      if (s.isNotEmpty) return s;
    } else if (raw != null && raw is! List) {
      final t = raw.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
  }
  return '';
}

/// Full quotation from `GET /api/v1/quotations/{id}/`.
@immutable
class QuotationDetailModel {
  const QuotationDetailModel({required this.id, required this.raw});

  final String id;
  final Map<String, dynamic> raw;

  String field(String camel, List<String> keys) {
    for (final k in keys) {
      final v = raw[k];
      if (v == null) continue;
      if (v is Map || v is List) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    return '—';
  }

  String get quoteName {
    for (final k in const ['quote_name', 'name', 'title', 'Subject']) {
      final v = raw[k];
      if (v == null) continue;
      if (v is Map || v is List) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    final p = projectLabel;
    if (p != '—' && p.trim().isNotEmpty) return p;
    final id = _readString(raw, const ['id', 'ID']);
    if (id.isNotEmpty) return 'Quotation #$id';
    return 'Untitled';
  }

  /// Prefer CRM serial (e.g. QUOTE062) for headings / chips.
  String get quotationSerialNumber {
    for (final k in const [
      'quotation_serial_number',
      'quote_serial_number',
      'serial_number',
    ]) {
      final v = raw[k];
      if (v == null) continue;
      if (v is Map || v is List) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    return '—';
  }

  String get listTitle {
    final serial = quotationSerialNumber;
    if (serial != '—') return serial;
    return quoteName;
  }

  String get quoteNumber {
    for (final k in const [
      'quotation_serial_number',
      'quote_number',
      'number',
      'Quote_Number',
      'reference',
    ]) {
      final v = raw[k];
      if (v == null) continue;
      if (v is Map || v is List) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    final order = _readString(raw, const ['order_number', 'order_no']);
    if (order.isNotEmpty) return order;
    return '—';
  }

  String get clientLabel {
    final n = _readNestedLabel(
      raw,
      const ['client', 'customer'],
      const ['name', 'client_name'],
    );
    return n.isNotEmpty ? n : field('client', const ['client_name']);
  }

  String get projectLabel {
    final n = _readNestedLabel(
      raw,
      const ['project', 'deal'],
      const ['name', 'project_name'],
    );
    return n.isNotEmpty ? n : field('project', const ['project_name']);
  }

  String get siteLabel {
    final top = _readNestedLabel(
      raw,
      const ['site'],
      const ['site_name', 'name'],
    );
    if (top.isNotEmpty) return top;
    final fromSites = _firstSitesArrayName(raw);
    if (fromSites != null && fromSites.isNotEmpty) return fromSites;
    final fromProject = _firstProjectSiteName(raw);
    if (fromProject != null && fromProject.isNotEmpty) return fromProject;
    return field('site', const ['site_name']);
  }

  String get costCentre =>
      field('costCentre', const ['cost_centre', 'cost_center']);

  /// For display: empty or em-dash becomes `-` (matches CRM overview).
  String get costCentreDisplay {
    final c = costCentre.trim();
    if (c.isEmpty || c == '—') return '-';
    return c;
  }

  List<QuotationTagChip> get tagChips => _parseTagChips(raw);

  String get dueDateDisplay {
    final d = dueDate.trim();
    if (d.isEmpty || d == '—') return '—';
    final parsed = DateTime.tryParse(d);
    if (parsed != null) {
      return DateFormat('MMM d, y').format(parsed).replaceAll(',', '');
    }
    return d;
  }

  /// First PDF / export URL found on the payload, if any.
  String? get exportPdfUrl {
    for (final k in const [
      'pdf_url',
      'export_pdf_url',
      'pdf',
      'document_url',
      'quote_pdf',
    ]) {
      final v = raw[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final nested = raw['pdf'] ?? raw['export'];
    if (nested is Map) {
      final m = Map<String, dynamic>.from(
        nested.map((k, v) => MapEntry(k.toString(), v)),
      );
      final u = _readString(m, const ['url', 'link', 'href', 'download']);
      if (u.isNotEmpty) return u;
    }
    return null;
  }

  List<dynamic> get rawBlocks {
    final b = raw['blocks'];
    if (b is List) return b;
    return const [];
  }

  /// Scope & pricing tree from `GET /quotations/{id}/` (`quote_sections`).
  List<dynamic> get quoteSectionsRaw {
    final sections = raw['quote_sections'];
    if (sections is List) return sections;
    return const [];
  }

  bool get hasQuoteSections => quoteSectionsRaw.isNotEmpty;

  String get primaryContact {
    final s = _displayContactObject(raw['primary_customer_contact']);
    if (s.isNotEmpty) return s;
    return field('primary', const ['primary_contact', 'contact_phone']);
  }

  String get secondaryContact {
    final rawAdd = raw['additional_customer_contact'];
    if (rawAdd is List && rawAdd.isNotEmpty) {
      final labels = rawAdd
          .map(_displayContactObject)
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (labels.isNotEmpty) return labels.join(', ');
    }
    final add = _displayContactObject(raw['additional_customer_contact']);
    if (add.isNotEmpty) return add;
    final sec = _displayContactObject(raw['secondary_customer_contact']);
    if (sec.isNotEmpty) return sec;
    return '—';
  }

  String get siteContact => field('siteContact', const ['site_contact']);

  String get tags {
    final formatted = _formatTagsField(raw);
    return formatted.isNotEmpty ? formatted : '—';
  }

  String get orderNo => field('orderNo', const ['order_number', 'order_no']);

  String get dueDate => field('dueDate', const ['due_date', 'valid_till']);

  String get projectManager {
    final v = raw['project_manager'];
    if (v is Map) {
      final s = _formatUserLike(v);
      if (s.isNotEmpty) return s;
    }
    return field('projectManager', const [
      'project_manager',
      'project_manager_name',
    ]);
  }

  String get technicians {
    final s = _formatTechniciansField(raw);
    return s.isNotEmpty ? s : '—';
  }

  String get salesPerson {
    final v = raw['salesperson'] ?? raw['sales_person'];
    if (v is Map) {
      final s = _formatUserLike(v);
      if (s.isNotEmpty) return s;
    }
    return field('salesPerson', const ['sales_person', 'salesperson']);
  }

  String get description =>
      field('description', const ['description', 'details']);

  factory QuotationDetailModel.fromJson(Map<String, dynamic> json) {
    final id = _readString(json, const ['id', 'ID']);
    return QuotationDetailModel(id: id.isEmpty ? '—' : id, raw: json);
  }
}
