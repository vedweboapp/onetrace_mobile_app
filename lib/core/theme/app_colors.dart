import 'package:flutter/material.dart';

/// Central palette for RED5 — use from screens and widgets instead of inline [Color] literals.
abstract final class AppColors {
  static const Color brandPrimary = Color(0xFFB70011);
  static const Color brandPrimaryContainer = Color(0x1AB70011);
  static const Color brandOnPrimary = Color(0xFFFFFFFF);

  /// Dashboard FAB and strong accents.
  static const Color accentRed = Color(0xFFDC2626);

  /// Errors, destructive snackbars, status “action required”.
  static const Color danger = Color(0xFFB42318);

  static const Color ink = Color(0xFF111827);
  static const Color inkStrong = Color(0xFF191C1D);
  static const Color inkInverse = Color(0xFF0F172A);

  static const Color muted = Color(0xFF6B7280);
  static const Color mutedLight = Color(0xFF9CA3AF);

  static const Color brown = Color(0xFF5C403C);
  static const Color brownMuted = Color(0x805C403C);

  static const Color border = Color(0xFFD1D5DB);
  static const Color borderLight = Color(0xFFE5E7EB);

  static const Color surface = Color(0xFFF3F4F6);
  static const Color surfaceHigh = Color(0xFFF9FAFB);
  static const Color surfaceCanvas = Color(0xFFE5E7EB);
  static const Color surfaceElevated = Color(0xFFF5F7FB);

  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);

  static const Color paginationText = Color(0xFF374151);
  static const Color iconDark = Color(0xFF1F2937);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorSurface = Color(0xFFFEE2E2);

  static const Color shadowSoft = Color(0x14251C1D);
  static const Color shadowCard = Color(0x12000000);
  static const Color shadowBar = Color(0x14000000);
  static const Color shadowElevated = Color(0x26251C1D);

  /// Login / [AppScreenBackground] gradient overlay.
  static const Color overlayGradientLight = Color(0xE6F8F9FA);
  static const Color overlayGradientDark = Color(0xCCD9DADB);
  static const Color imageFallback = Color(0xFFE7E8E9);

  static const Color searchFill = Color(0xFFEFF0F5);
  static const Color pdfViewerBackground = Color(0xFFF3F4F6);

  static const Color success = Color(0xFF34D399);
  static const Color successMuted = Color(0x1434D399);

  static const Color darkBar = Color(0xFF1F2937);
  static const Color darkBarBorder = Color(0xFF374151);

  static const Color pinSheetPrimaryOutline = Color(0x33B70011);

  // Quote canvas / markup
  static const Color markupFill = Color(0x33B70011);
  static const Color markupStroke = Color(0xFFB70011);
  static const Color markupFillCommitted = Color(0x12B70011);
  static const Color markupStrokeCommitted = Color(0x99B70011);
  static const Color markupScrim = Color(0x33000000);
  static const Color markupTooltipBg = Color(0xF2FFFFFF);

  static const Color plotPinRose = Color(0xFFE11D48);
  static const Color plotPinBlue = Color(0xFF2563EB);
  static const Color plotPinGreen = Color(0xFF059669);
  static const Color plotPinAmber = Color(0xFFD97706);
  static const Color plotPinViolet = Color(0xFF7C3AED);
  static const Color plotPinCyan = Color(0xFF0891B2);

  // Pin detail sheet status chips
  static const Color statusInstalledBg = Color(0xFFE9F9EE);
  static const Color statusInstalledFg = Color(0xFF137333);
  static const Color statusProgressBg = Color(0xFFFEF3E8);
  static const Color statusProgressFg = Color(0xFFB54708);
  static const Color statusActionBg = Color(0xFFFDECEC);
  static const Color statusActionFg = Color(0xFFB42318);
  static const Color statusDefaultBg = Color(0xFFE0F2FE);
  static const Color statusDefaultFg = Color(0xFF0B6E99);

  static const Color scrimDark = Color(0xCC111827);
  static const Color sheetBarrier = Color(0x33000000);
  static const Color navInactive = Color(0xFF0F172A);

  static const Color authFieldSurface = Color(0x80E1E3E4);

  /// Universal outlined text fields (login + dialogs + sheets).
  static const Color textFieldBorder = Color(0xFFE0E0E0);
  static const Color textFieldFocusBorder = Color(0xFF111111);
  static const Color textFieldHint = Color(0xFF9E9E9E);
  static const Color textFieldForeground = Color(0xFF111111);

  static const Color disabledButton = Color(0xFFD1D5DB);
  static const Color disabledOnButton = Color(0xFF9CA3AF);

  static const Color neutralGradientStart = Color(0xFFD1D5DB);
  static const Color neutralGradientEnd = Color(0xFF1F2937);
}
