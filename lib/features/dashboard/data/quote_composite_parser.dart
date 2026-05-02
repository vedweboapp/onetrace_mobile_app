import 'package:red5/features/dashboard/data/quote_composite_models.dart';

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
