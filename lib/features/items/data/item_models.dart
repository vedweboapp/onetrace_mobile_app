import 'package:flutter/foundation.dart';

@immutable
class ItemModel {
  const ItemModel({
    required this.id,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.costPrice,
    required this.sellPrice,
  });

  final String id;
  final String name;
  final String sku;
  final double quantity;
  final double costPrice;
  final double sellPrice;

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: _readString(json, const ['id']),
      name: _readString(
        json,
        const ['name', 'item_name', 'title', 'product_name'],
        fallback: 'Item',
      ),
      sku: _readString(
        json,
        const ['sku', 'item_code', 'code', 'SKU', 'product_code'],
      ),
      quantity: _readDouble(json, const [
        'quantity',
        'qty',
        'quantity_on_hand',
        'stock_quantity',
        'on_hand',
      ]),
      costPrice: _readDouble(json, const [
        'cost_price',
        'cost',
        'unit_cost',
        'purchase_price',
      ]),
      sellPrice: _readDouble(json, const [
        'selling_price',
        'sell_price',
        'price',
        'sale_price',
        'unit_price',
      ]),
    );
  }
}

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

double _readDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      final v = double.tryParse(t.replaceAll(',', ''));
      if (v != null) return v;
    }
  }
  return 0;
}

bool _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final t = raw.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
  }
  return false;
}

/// One line item inside a composite parent (`GET /item/{id}/` may nest `item` / ids).
@immutable
class ItemComponentLine {
  const ItemComponentLine({
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.quantity,
  });

  final String itemId;
  final String itemName;
  final String sku;
  final double quantity;

  factory ItemComponentLine.fromNestedJson(Map<String, dynamic> json) {
    final nestedRaw = json['item'] ?? json['child_item'] ?? json['product'];
    Map<String, dynamic> nested = const <String, dynamic>{};
    var resolvedId = _readString(json, const [
      'item_id',
      'child_item_id',
      'product_id',
    ]);

    if (nestedRaw is Map) {
      nested = Map<String, dynamic>.from(
        nestedRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
      if (resolvedId.isEmpty) {
        resolvedId = _readString(nested, const ['id']);
      }
    } else if (nestedRaw != null && resolvedId.isEmpty) {
      resolvedId = nestedRaw.toString().trim();
    }

    final name = _readString(nested, const [
      'name',
      'item_name',
      'title',
      'product_name',
    ]);
    final sku = _readString(nested, const [
      'sku',
      'item_code',
      'code',
      'SKU',
    ]);

    return ItemComponentLine(
      itemId: resolvedId,
      itemName: name.isNotEmpty ? name : 'Component',
      sku: sku,
      quantity: _readDouble(json, const ['quantity', 'qty', 'amount']),
    );
  }
}

/// Full row from `GET /api/v1/item/{id}/` for the detail screen.
@immutable
class ItemDetailModel {
  const ItemDetailModel({
    required this.id,
    required this.name,
    required this.sku,
    required this.reorderQuantity,
    required this.quantity,
    required this.itemTypeLabel,
    required this.isComposite,
    required this.components,
    required this.costPrice,
    required this.sellPrice,
    required this.createdAtDisplay,
    required this.updatedAtDisplay,
    required this.createdByUsername,
    required this.createdByEmail,
    required this.modifiedByUsername,
    required this.modifiedByEmail,
  });

  final String id;
  final String name;
  final String sku;
  final double reorderQuantity;
  final double quantity;
  final String itemTypeLabel;
  final bool isComposite;
  final List<ItemComponentLine> components;
  final double costPrice;
  final double sellPrice;
  final String createdAtDisplay;
  final String updatedAtDisplay;
  final String createdByUsername;
  final String createdByEmail;
  final String modifiedByUsername;
  final String modifiedByEmail;

  bool get hasModifiedBy =>
      modifiedByUsername.trim().isNotEmpty || modifiedByEmail.trim().isNotEmpty;

  factory ItemDetailModel.fromJson(Map<String, dynamic> json) {
    final isComposite = _readBool(json, const ['is_composite', 'isComposite']);
    final typeStr = _readString(
      json,
      const ['item_type', 'type', 'itemType', 'category_name'],
    );
    final itemTypeLabel = typeStr.isNotEmpty
        ? typeStr
        : (isComposite ? 'Composite item' : 'Standard item');

    final created = _parseActor(json, 'created_by');
    final modified = _parseActor(json, 'modified_by');
    final components = _parseItemComponents(json);

    return ItemDetailModel(
      id: _readString(json, const ['id']),
      name: _readString(
        json,
        const ['name', 'item_name', 'title', 'product_name'],
        fallback: 'Item',
      ),
      sku: _readString(
        json,
        const ['sku', 'item_code', 'code', 'SKU', 'product_code'],
      ),
      reorderQuantity: _readDouble(json, const [
        'reorder_quantity',
        'reorder_qty',
        'reorder_point',
        'min_stock',
        'minimum_quantity',
      ]),
      quantity: _readDouble(json, const [
        'quantity',
        'qty',
        'quantity_on_hand',
        'stock_quantity',
        'on_hand',
      ]),
      itemTypeLabel: itemTypeLabel,
      isComposite: isComposite,
      components: components,
      costPrice: _readDouble(json, const [
        'cost_price',
        'cost',
        'unit_cost',
        'purchase_price',
      ]),
      sellPrice: _readDouble(json, const [
        'selling_price',
        'sell_price',
        'price',
        'sale_price',
        'unit_price',
      ]),
      createdAtDisplay: _formatItemTimestamp(
        _readString(json, const ['created_at', 'createdAt']),
      ),
      updatedAtDisplay: _formatItemTimestamp(
        _readString(json, const [
          'updated_at',
          'modified_at',
          'modifiedAt',
          'updatedAt',
        ]),
      ),
      createdByUsername: created.$1,
      createdByEmail: created.$2,
      modifiedByUsername: modified.$1,
      modifiedByEmail: modified.$2,
    );
  }

  static List<ItemComponentLine> _parseItemComponents(Map<String, dynamic> json) {
    dynamic raw;
    for (final key in const [
      'components',
      'composite_items',
      'item_items',
      'child_items',
      'bom',
      'bom_lines',
      'line_items',
      'items',
    ]) {
      final v = json[key];
      if (v is List && v.isNotEmpty) {
        raw = v;
        break;
      }
    }
    if (raw is! List) return const <ItemComponentLine>[];

    final out = <ItemComponentLine>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(
        e.map((k, v) => MapEntry(k.toString(), v)),
      );
      final line = ItemComponentLine.fromNestedJson(m);
      if (line.itemId.isNotEmpty) {
        out.add(line);
      }
    }
    return out;
  }

  /// `(usernameOrName, email)` from `created_by` / `created_by_details` style maps.
  static (String, String) _parseActor(
    Map<String, dynamic> json,
    String baseKey,
  ) {
    for (final key in ['${baseKey}_details', baseKey]) {
      final v = json[key];
      if (v is! Map) continue;
      final m = Map<String, dynamic>.from(
        v.map((k, val) => MapEntry(k.toString(), val)),
      );
      final username = _readString(m, const [
        'username',
        'user_name',
        'full_name',
        'name',
      ]);
      final email = _readString(m, const ['email', 'email_address']);
      if (username.isNotEmpty || email.isNotEmpty) {
        return (username, email);
      }
    }
    return ('', '');
  }

  static String _formatItemTimestamp(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t == 'null') return '—';
    final dt = DateTime.tryParse(t);
    if (dt == null) return t;
    final local = dt.toLocal();
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    var hour = local.hour;
    final isPm = hour >= 12;
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = isPm ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year}, $hour:$min $ampm';
  }
}
