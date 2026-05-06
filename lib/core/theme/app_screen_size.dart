import 'package:flutter/material.dart';

/// Width thresholds aligned with Material 3 window size classes.
/// Auth flows use [compactLayoutMaxWidth] for the phone vs wide split.
abstract final class AppBreakpoints {
  /// Layouts narrower than this use compact / “phone” chrome (e.g. login stack).
  static const double compactLayoutMaxWidth = 600;

  /// Between compact and medium desktop.
  static const double mediumLayoutMaxWidth = 840;

  /// Large desktop / two-pane layouts.
  static const double expandedLayoutMinWidth = 1200;
}

/// Screen metrics and layout buckets — prefer this over ad-hoc [MediaQuery] reads.
abstract final class AppScreenSize {
  const AppScreenSize._();

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static double widthOf(BuildContext context) => sizeOf(context).width;

  static double heightOf(BuildContext context) => sizeOf(context).height;

  static double shortestSideOf(BuildContext context) {
    final s = sizeOf(context);
    return s.width < s.height ? s.width : s.height;
  }

  static EdgeInsets paddingOf(BuildContext context) =>
      MediaQuery.paddingOf(context);

  static EdgeInsets viewInsetsOf(BuildContext context) =>
      MediaQuery.viewInsetsOf(context);

  static double keyboardInsetBottomOf(BuildContext context) =>
      viewInsetsOf(context).bottom;

  static Orientation orientationOf(BuildContext context) =>
      MediaQuery.orientationOf(context);

  /// `true` when width is below [AppBreakpoints.compactLayoutMaxWidth].
  static bool isCompactLayout(BuildContext context) =>
      widthOf(context) < AppBreakpoints.compactLayoutMaxWidth;

  /// Width in \[[AppBreakpoints.compactLayoutMaxWidth], [AppBreakpoints.mediumLayoutMaxWidth])\`.
  static bool isMediumLayout(BuildContext context) {
    final w = widthOf(context);
    return w >= AppBreakpoints.compactLayoutMaxWidth &&
        w < AppBreakpoints.mediumLayoutMaxWidth;
  }

  /// Width at or above [AppBreakpoints.mediumLayoutMaxWidth].
  static bool isLargeLayout(BuildContext context) =>
      widthOf(context) >= AppBreakpoints.mediumLayoutMaxWidth;

  /// Width at or above [AppBreakpoints.expandedLayoutMinWidth].
  static bool isExpandedLayout(BuildContext context) =>
      widthOf(context) >= AppBreakpoints.expandedLayoutMinWidth;
}

extension AppScreenSizeContext on BuildContext {
  Size get appScreenSize => AppScreenSize.sizeOf(this);

  double get appScreenWidth => AppScreenSize.widthOf(this);

  double get appScreenHeight => AppScreenSize.heightOf(this);

  double get appScreenShortestSide => AppScreenSize.shortestSideOf(this);

  EdgeInsets get appScreenPadding => AppScreenSize.paddingOf(this);

  EdgeInsets get appScreenViewInsets => AppScreenSize.viewInsetsOf(this);

  double get appKeyboardInsetBottom => AppScreenSize.keyboardInsetBottomOf(this);

  bool get isCompactLayout => AppScreenSize.isCompactLayout(this);

  bool get isMediumLayout => AppScreenSize.isMediumLayout(this);

  bool get isLargeLayout => AppScreenSize.isLargeLayout(this);

  bool get isExpandedLayout => AppScreenSize.isExpandedLayout(this);
}
