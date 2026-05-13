import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increment from the dashboard after creating a quotation so the list refetches.
final quotationListRefreshTickProvider = StateProvider<int>((ref) => 0);
