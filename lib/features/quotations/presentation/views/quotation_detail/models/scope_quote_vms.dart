part of '../quotation_detail.dart';

@immutable
class _QuoteSectionVm {
  const _QuoteSectionVm({
    required this.name,
    required this.sectionOrder,
    required this.sectionTotal,
    required this.plots,
    this.levelId,
  });

  final String name;
  final int sectionOrder;
  final double sectionTotal;
  final int? levelId;
  final List<_QuotePlotVm> plots;

  factory _QuoteSectionVm.fromMap(Map<String, dynamic> m) {
    final plots = <_QuotePlotVm>[];
    final rawPlots = m['plots'];
    if (rawPlots is List) {
      for (final p in rawPlots) {
        plots.add(_QuotePlotVm.fromMap(_scopeAsMap(p)));
      }
    }
    plots.sort((a, b) => a.plotOrder.compareTo(b.plotOrder));
    return _QuoteSectionVm(
      name: (m['name'] ?? 'Block').toString().trim().isEmpty
          ? 'Block'
          : (m['name'] ?? 'Block').toString().trim(),
      sectionOrder: _scopeParseInt(m['section_order']),
      sectionTotal: _scopeParseDouble(m['section_total']),
      levelId: _scopeParseIntOrNull(m['level_id']),
      plots: plots,
    );
  }
}

@immutable
class _QuotePlotVm {
  const _QuotePlotVm({
    required this.name,
    required this.plotOrder,
    required this.plotTotal,
    required this.pins,
    this.plotId,
  });

  final String name;
  final int plotOrder;
  final double plotTotal;
  final int? plotId;
  final List<_QuotePinVm> pins;

  factory _QuotePlotVm.fromMap(Map<String, dynamic> m) {
    final pins = <_QuotePinVm>[];
    final rawPins = m['pins'];
    if (rawPins is List) {
      for (final p in rawPins) {
        pins.add(_QuotePinVm.fromMap(_scopeAsMap(p)));
      }
    }
    pins.sort((a, b) => a.pinsOrder.compareTo(b.pinsOrder));
    return _QuotePlotVm(
      name: (m['name'] ?? 'Plot').toString().trim().isEmpty
          ? 'Plot'
          : (m['name'] ?? 'Plot').toString().trim(),
      plotOrder: _scopeParseInt(m['plot_order']),
      plotTotal: _scopeParseDouble(m['plot_total']),
      plotId: _scopeParseIntOrNull(m['plot_id']),
      pins: pins,
    );
  }
}

@immutable
class _QuotePinVm {
  const _QuotePinVm({
    required this.name,
    required this.pinsOrder,
    required this.quantity,
    required this.sellingPrice,
    required this.pinsTotal,
    required this.isComposite,
    required this.compositeItems,
    this.pinId,
    this.compositeItemId,
  });

  final String name;
  final int pinsOrder;
  final int quantity;
  final double sellingPrice;
  final double pinsTotal;
  final bool isComposite;
  final int? pinId;
  final int? compositeItemId;
  final List<_QuoteCompositeItemVm> compositeItems;

  factory _QuotePinVm.fromMap(Map<String, dynamic> m) {
    final compositeItems = <_QuoteCompositeItemVm>[];
    final rawChildren = m['composite_items'];
    if (rawChildren is List) {
      for (final c in rawChildren) {
        compositeItems.add(_QuoteCompositeItemVm.fromMap(_scopeAsMap(c)));
      }
    }
    return _QuotePinVm(
      name: (m['name'] ?? 'Quoted item').toString().trim().isEmpty
          ? 'Quoted item'
          : (m['name'] ?? 'Quoted item').toString().trim(),
      pinsOrder: _scopeParseInt(m['pins_order']),
      quantity: _scopeParseInt(m['quantity'], fallback: 1),
      sellingPrice: _scopeParseDouble(m['selling_price']),
      pinsTotal: _scopeParseDouble(m['pins_total']),
      isComposite: m['is_composite'] == true,
      pinId: _scopeParseIntOrNull(m['pin_id']),
      compositeItemId: _scopeParseIntOrNull(m['composite_item_id']),
      compositeItems: compositeItems,
    );
  }
}

@immutable
class _QuoteCompositeItemVm {
  const _QuoteCompositeItemVm({
    required this.childItemName,
    required this.quantity,
    this.childItemId,
  });

  final String childItemName;
  final int quantity;
  final int? childItemId;

  factory _QuoteCompositeItemVm.fromMap(Map<String, dynamic> m) {
    return _QuoteCompositeItemVm(
      childItemName:
          (m['child_item_name'] ?? m['name'] ?? 'Item').toString().trim(),
      quantity: _scopeParseInt(m['quantity'], fallback: 1),
      childItemId: _scopeParseIntOrNull(m['child_item_id']),
    );
  }
}

int _scopeParseInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? fallback;
}

int? _scopeParseIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
