import 'package:flutter/material.dart';

import 'app_screen_size.dart';

/// Screen width / height and layout buckets: [AppScreenSize] and [AppScreenSizeContext].
///
/// Shared paddings and insets for stacked photo backgrounds + transparent app bars.
abstract final class AppLayout {
  static double bodyTopBelowAppBar(BuildContext context, {double extra = 8}) {
    return AppScreenSize.paddingOf(context).top + kToolbarHeight + extra;
  }

  static double quoteProjectBodyTop(BuildContext context) {
    return AppScreenSize.paddingOf(context).top + kToolbarHeight + 2;
  }
}
