import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumps when the dashboard jobs list should reload (e.g. after create).
final jobsListRefreshTickProvider = StateProvider<int>((ref) => 0);
