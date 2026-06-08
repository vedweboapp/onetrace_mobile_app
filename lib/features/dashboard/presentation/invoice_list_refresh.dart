import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bump after creating an invoice so the dashboard list refetches.
final invoiceListRefreshTickProvider = StateProvider<int>((ref) => 0);
