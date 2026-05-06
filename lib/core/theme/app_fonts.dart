import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppFonts {
  const AppFonts._();

  /// Primary UI font family (Inter). Use with [ThemeData.fontFamily] for defaults.
  static String? get fontFamily => GoogleFonts.inter().fontFamily;

  // ─── Base constructor ────────────────────────────────────────────────────────

  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? height,
    double? letterSpacing,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
    );
  }

  static TextTheme interTextTheme(TextTheme base) =>
      GoogleFonts.interTextTheme(base);

  // ─── Display ─────────────────────────────────────────────────────────────────

  /// 57 sp · Regular · −0.25 tracking  (M3 displayLarge)
  static TextStyle displayLarge({Color? color, bool italic = false}) => inter(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: -0.25,
    height: 1.12,
    color: color,
  );

  /// 45 sp · Regular  (M3 displayMedium)
  static TextStyle displayMedium({Color? color, bool italic = false}) => inter(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: 1.16,
    color: color,
  );

  /// 36 sp · Regular  (M3 displaySmall)
  static TextStyle displaySmall({Color? color, bool italic = false}) => inter(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: 1.22,
    color: color,
  );

  // ─── Headline ────────────────────────────────────────────────────────────────

  /// 32 sp · SemiBold  (M3 headlineLarge)
  static TextStyle headlineLarge({Color? color, bool italic = false}) => inter(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: 1.25,
    color: color,
  );

  /// 28 sp · SemiBold  (M3 headlineMedium)
  static TextStyle headlineMedium({Color? color, bool italic = false}) => inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: 1.29,
    color: color,
  );

  /// 24 sp · SemiBold  (M3 headlineSmall)
  static TextStyle headlineSmall({Color? color, bool italic = false}) => inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: 1.33,
    color: color,
  );

  // ─── Title ───────────────────────────────────────────────────────────────────

  /// 22 sp · Medium  (M3 titleLarge)
  static TextStyle titleLarge({Color? color, bool italic = false}) => inter(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: 1.27,
    color: color,
  );

  /// 16 sp · Medium · +0.15 tracking  (M3 titleMedium)
  static TextStyle titleMedium({Color? color, bool italic = false}) => inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: 0.15,
    height: 1.50,
    color: color,
  );

  /// 14 sp · Medium · +0.1 tracking  (M3 titleSmall)
  static TextStyle titleSmall({Color? color, bool italic = false}) => inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: 0.1,
    height: 1.43,
    color: color,
  );

  // ─── Body ────────────────────────────────────────────────────────────────────

  /// 16 sp · Regular · +0.5 tracking  (M3 bodyLarge)
  static TextStyle bodyLarge({Color? color, bool italic = false}) => inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: 0.5,
    height: 1.50,
    color: color,
  );

  /// 14 sp · Regular · +0.25 tracking  (M3 bodyMedium) — default prose style
  static TextStyle bodyMedium({Color? color, bool italic = false}) => inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: 0.25,
    height: 1.43,
    color: color,
  );

  /// 12 sp · Regular · +0.4 tracking  (M3 bodySmall)
  static TextStyle bodySmall({Color? color, bool italic = false}) => inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: 0.4,
    height: 1.33,
    color: color,
  );

  // ─── Label ───────────────────────────────────────────────────────────────────

  /// 14 sp · Medium · +0.1 tracking  (M3 labelLarge) — buttons, tabs
  static TextStyle labelLarge({Color? color, bool italic = false}) => inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: 0.1,
    height: 1.43,
    color: color,
  );

  /// 12 sp · Medium · +0.5 tracking  (M3 labelMedium) — chips, badges
  static TextStyle labelMedium({Color? color, bool italic = false}) => inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: 0.5,
    height: 1.33,
    color: color,
  );

  /// 11 sp · Medium · +0.5 tracking  (M3 labelSmall) — captions, overlines
  static TextStyle labelSmall({Color? color, bool italic = false}) => inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: 0.5,
    height: 1.45,
    color: color,
  );
}
