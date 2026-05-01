import 'package:red5/features/dashboard/data/quote_composite_models.dart';

List<Map<String, dynamic>>? _asMapList(dynamic raw) {
  if (raw is! List) return null;
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is Map<String, dynamic>) {
      out.add(e);
    } else if (e is Map) {
      out.add(Map<String, dynamic>.from(e));
    }
  }
  return out;
}

String? _readString(Map<String, dynamic> m, List<String> keys) {
  for (final key in keys) {
    final value = m[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? _groupTitleFromMap(Map<String, dynamic> g) {
  return _readString(g, [
        'Name',
        'name',
        'Group_Name',
        'group_name',
        'Composite_Group_Name',
        'Title',
        'title',
        'Subject',
        'subject',
        'Composite_Item_Name',
        'Product_Name',
      ]) ??
      (() {
        final pn = g['Product_Name'];
        if (pn is Map) {
          final n = pn['name'];
          if (n is String && n.trim().isNotEmpty) return n.trim();
        }
        return null;
      })();
}

List<dynamic>? _nestedItemsFromGroupMap(Map<String, dynamic> g) {
  for (final key in [
    'Composite_Items',
    'composite_items',
    'Items',
    'items',
    'Product_Details',
    'product_details',
    'Line_Items',
    'line_items',
    'Mapped_Items',
    'mapped_items',
    'Subform_Items',
    'subform_items',
  ]) {
    final v = g[key];
    if (v is List && v.isNotEmpty) return v;
  }
  return null;
}

/// Collects composite item groups from a CRM Quote record map.
List<QuoteCompositeItemGroup> parseCompositeItemGroupsFromZohoRecord(
  Map<String, dynamic> record,
) {
  final groups = <QuoteCompositeItemGroup>[];

  void addGroup(String title, List<QuoteCompositeItem> items) {
    if (items.isEmpty) return;
    final t = title.trim().isEmpty ? 'Composite group' : title.trim();
    groups.add(QuoteCompositeItemGroup(title: t, items: items));
  }

  for (final key in [
    'Composite_Item_Groups',
    'Composite_Items_Groups',
    'composite_item_groups',
    'Composite_Item_Details',
    'composite_item_details',
    'Line_Item_Groups',
    'line_item_groups',
  ]) {
    final list = _asMapList(record[key]);
    if (list == null) continue;
    for (final g in list) {
      final nested = _nestedItemsFromGroupMap(g);
      if (nested == null) continue;
      final items = <QuoteCompositeItem>[];
      for (final row in nested) {
        if (row is! Map) continue;
        final m = Map<String, dynamic>.from(row);
        final item = QuoteCompositeItem.fromZohoLineMap(m);
        if (item != null) items.add(item);
      }
      final title = _groupTitleFromMap(g) ?? 'Composite group';
      addGroup(title, items);
    }
  }

  final quotedItems = record['Quoted_Items'];
  final productDetails = record['Product_Details'];
  final lineRows = quotedItems is List && quotedItems.isNotEmpty
      ? quotedItems
      : (productDetails is List ? productDetails : null);
  final rows = _asMapList(lineRows);
  if (rows != null) {
    for (final row in rows) {
      final nested = _nestedItemsFromGroupMap(row);
      if (nested == null) continue;
      final items = <QuoteCompositeItem>[];
      for (final child in nested) {
        if (child is! Map) continue;
        final m = Map<String, dynamic>.from(child);
        final item = QuoteCompositeItem.fromZohoLineMap(m);
        if (item != null) items.add(item);
      }
      if (items.isEmpty) continue;
      final parentName = _groupTitleFromMap(row) ?? 'Composite items';
      addGroup(parentName, items);
    }
  }

  return groups;
}

/// Sample bundles for routing preview (no live CRM record).
List<QuoteCompositeItemGroup> sampleCompositeItemGroupsForRouting() {
  return [
    QuoteCompositeItemGroup(
      title: 'Sample bundle A',
      items: const [
        QuoteCompositeItem(name: 'Component one', quantity: 1, total: 49.99, sku: 'SKU-001'),
        QuoteCompositeItem(name: 'Component two', quantity: 2, total: 30.00, sku: 'SKU-002'),
      ],
    ),
    QuoteCompositeItemGroup(
      title: 'Sample bundle B',
      items: const [
        QuoteCompositeItem(name: 'Component three', quantity: 1, total: 199.00),
      ],
    ),
  ];
}
