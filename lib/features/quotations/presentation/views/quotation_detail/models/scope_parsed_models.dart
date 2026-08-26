part of '../quotation_detail.dart';

class _ScopeParsedBlock {
  _ScopeParsedBlock({required this.name, required this.sections});

  final String name;
  final List<_ScopeParsedSection> sections;

  factory _ScopeParsedBlock.fromMap(Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString().trim();
    final rawSecs = m['sections'];
    final sections = <_ScopeParsedSection>[];
    if (rawSecs is List) {
      for (final s in rawSecs) {
        sections.add(_ScopeParsedSection.fromMap(_scopeAsMap(s)));
      }
    }
    if (sections.isEmpty) {
      sections.add(_ScopeParsedSection(name: '', lines: const []));
    }
    return _ScopeParsedBlock(
      name: name.isEmpty ? 'Block' : name,
      sections: sections,
    );
  }
}

class _ScopeParsedSection {
  _ScopeParsedSection({required this.name, required this.lines});

  final String name;
  final List<Map<String, dynamic>> lines;

  factory _ScopeParsedSection.fromMap(Map<String, dynamic> m) {
    final name = (m['name'] ?? 'Section').toString().trim();
    final rawItems = m['line_items'] ?? m['items'] ?? m['lines'];
    final lines = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        final im = _scopeAsMap(it);
        if (im.isNotEmpty) lines.add(im);
      }
    }
    return _ScopeParsedSection(
      name: name.isEmpty ? 'Section' : name,
      lines: lines,
    );
  }
}

class _ScopeTotals {
  const _ScopeTotals({
    required this.subTotal,
    required this.discount,
    required this.tax,
    required this.adjustment,
    required this.grandTotal,
  });

  final double subTotal;
  final double discount;
  final double tax;
  final double adjustment;
  final double grandTotal;

  factory _ScopeTotals.fromLineItems(List<Map<String, dynamic>> items) {
    var listSub = 0.0;
    var disc = 0.0;
    var tax = 0.0;
    var gross = 0.0;
    for (final m in items) {
      disc += _scopeParseDouble(m['discount'] ?? m['discount_amount']);
      tax += _scopeParseDouble(m['tax'] ?? m['tax_amount']);
      final qtyRaw = _scopeParseDouble(m['quantity'] ?? m['qty']);
      final qty = qtyRaw > 0 ? qtyRaw : 1.0;
      final list = _scopeParseDouble(
        m['list_price'] ?? m['listPrice'] ?? m['unit_price'],
      );
      final amt = _scopeParseDouble(m['amount']);
      final tot = _scopeParseDouble(m['total'] ?? m['line_total']);

      if (list > 0) {
        listSub += list * qty;
      } else if (amt > 0) {
        listSub += amt;
      } else {
        listSub += tot;
      }

      if (tot > 0) {
        gross += tot;
      } else if (amt > 0) {
        gross += amt;
      } else if (list > 0) {
        gross += list * qty;
      }
    }
    const adjustment = 0.0;
    final subDisplay = listSub > 0 ? listSub : gross;
    final grand = (gross - disc + tax + adjustment).clamp(0.0, double.infinity);
    return _ScopeTotals(
      subTotal: subDisplay,
      discount: disc,
      tax: tax,
      adjustment: adjustment,
      grandTotal: grand,
    );
  }
}
