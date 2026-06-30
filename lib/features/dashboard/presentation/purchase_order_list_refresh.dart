import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bump after creating a purchase order so the dashboard list refetches.
final purchaseOrderListRefreshTickProvider = StateProvider<int>((ref) => 0);
