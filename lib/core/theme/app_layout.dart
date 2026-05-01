import 'package:flutter/material.dart';

/// Shared paddings and insets for stacked photo backgrounds + transparent app bars.
abstract final class AppLayout {
  static double bodyTopBelowAppBar(BuildContext context, {double extra = 8}) {
    return MediaQuery.of(context).padding.top + kToolbarHeight + extra;
  }

  static double quoteProjectBodyTop(BuildContext context) {
    return MediaQuery.of(context).padding.top + kToolbarHeight + 2;
  }
}
