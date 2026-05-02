/// One component row inside a composite bundle (CRM subform / line child).
class QuoteCompositeItem {
  const QuoteCompositeItem({
    required this.name,
    this.quantity,
    this.total,
    this.sku,
    this.description,
  });

  final String name;
  final int? quantity;
  final double? total;
  final String? sku;
  final String? description;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (quantity != null) 'quantity': quantity,
    if (total != null) 'total': total,
    if (sku != null && sku!.isNotEmpty) 'sku': sku,
    if (description != null && description!.isNotEmpty) 'description': description,
  };

  factory QuoteCompositeItem.fromJson(Map<String, dynamic> json) {
    return QuoteCompositeItem(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Item',
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : int.tryParse('${json['quantity']}'),
      total: json['total'] is num
          ? (json['total'] as num).toDouble()
          : double.tryParse('${json['total']}'),
      sku: (json['sku'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
    );
  }
}

class QuoteCompositeItemGroup {
  const QuoteCompositeItemGroup({required this.title, required this.items});

  final String title;
  final List<QuoteCompositeItem> items;

  Map<String, dynamic> toJson() => {
    'title': title,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory QuoteCompositeItemGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <QuoteCompositeItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(QuoteCompositeItem.fromJson(raw));
        } else if (raw is Map) {
          items.add(QuoteCompositeItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    final title = (json['title'] as String?)?.trim();
    return QuoteCompositeItemGroup(
      title: (title == null || title.isEmpty) ? 'Group' : title,
      items: items,
    );
  }
}

List<QuoteCompositeItemGroup> compositeGroupsFromJson(dynamic raw) {
  if (raw is! List) return const [];
  final out = <QuoteCompositeItemGroup>[];
  for (final e in raw) {
    if (e is Map<String, dynamic>) {
      out.add(QuoteCompositeItemGroup.fromJson(e));
    } else if (e is Map) {
      out.add(QuoteCompositeItemGroup.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return out;
}
