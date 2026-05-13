import 'package:flutter/material.dart';
import 'package:red5/features/items/presentation/views/item_detail_page.dart';

/// Detail screen for a catalog row opened from the composite-items list.
///
/// Uses the shared [ItemDetailPage] (same routes as standard items) so URLs
/// and behaviour stay consistent.
class CompositeItemDetailsPage extends StatelessWidget {
  const CompositeItemDetailsPage({super.key, required this.itemId});

  final String itemId;

  /// Same path scheme as [ItemDetailPage].
  static String pathFor(String id) => ItemDetailPage.pathFor(id);

  @override
  Widget build(BuildContext context) {
    return ItemDetailPage(itemId: itemId);
  }
}
