import 'package:flutter/material.dart';

String toHexRgb(Color color) {
  final v = color.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color? parseHexColor(String raw) {
  final normalized = raw.trim().replaceAll('#', '');
  if (normalized.length != 6) return null;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// Readable text on top of [bg] (for pin status / tag API `text_colour`).
Color contrastTextForBackground(Color bg) {
  final luminance = bg.computeLuminance();
  return luminance > 0.45 ? const Color(0xFF111827) : Colors.white;
}

String contrastTextHexForBg(Color bg) => toHexRgb(contrastTextForBackground(bg));

bool colorsEqual(Color a, Color b) => toHexRgb(a) == toHexRgb(b);
