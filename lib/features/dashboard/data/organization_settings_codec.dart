import 'dart:convert';

/// Maps company-settings UI values to/from API field formats.
abstract final class OrganizationSettingsCodec {
  OrganizationSettingsCodec._();

  static const maxDigitSeparatorLength = 10;

  /// JSON array for API validation, e.g. `["Monday","Tuesday"]`.
  static List<String> workingDaysToApi(List<String> days) {
    return days.map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
  }

  /// Legacy PostgreSQL literal — parse only, do not send on PUT.
  static String workingDaysToPostgresArray(List<String> days) {
    if (days.isEmpty) return '{}';
    final elements = days
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .map(_quotePostgresArrayElement)
        .join(',');
    return '{$elements}';
  }

  /// Parses JSON list, PostgreSQL `{a,b}`, or legacy JSON-array string.
  static List<String> workingDaysFromApi(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    if (text.startsWith('{') && text.endsWith('}')) {
      final inner = text.substring(1, text.length - 1).trim();
      if (inner.isEmpty) return const [];
      return _splitPostgresArrayElements(inner);
    }
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return workingDaysFromApi(decoded);
      } catch (_) {
        return const [];
      }
    }
    return [text];
  }

  static String _quotePostgresArrayElement(String value) {
    if (RegExp(r'[,{}\"\\\s]').hasMatch(value)) {
      final escaped = value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
      return '"$escaped"';
    }
    return value;
  }

  static List<String> _splitPostgresArrayElements(String inner) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < inner.length; i++) {
      final ch = inner[i];
      if (ch == '"' && (i == 0 || inner[i - 1] != r'\')) {
        inQuotes = !inQuotes;
        continue;
      }
      if (ch == ',' && !inQuotes) {
        final item = buf.toString().trim();
        if (item.isNotEmpty) out.add(item);
        buf.clear();
        continue;
      }
      buf.write(ch);
    }
    final last = buf.toString().trim();
    if (last.isNotEmpty) out.add(last);
    return out;
  }

  static const _digitSeparatorUiToApi = <String, String>{
    '12,34,567.89': '12,34,567',
    '1,234,567.89': '1,234,567',
    '1.234.567,89': '1.234.567',
    'indian': '12,34,567',
    'western': '1,234,567',
    'us': '1,234,567',
    'european': '1.234.567',
  };

  static const _digitSeparatorApiToUi = <String, String>{
    '12,34,567': '12,34,567.89',
    '1,234,567': '1,234,567.89',
    '1.234.567': '1.234.567,89',
    'indian': '12,34,567.89',
    'western': '1,234,567.89',
    'us': '1,234,567.89',
    'european': '1.234.567,89',
  };

  /// API allows max 10 characters (not full preview samples).
  static String digitSeparatorToApi(String uiPattern) {
    final trimmed = uiPattern.trim();
    if (trimmed.isEmpty) return trimmed;
    final mapped = _digitSeparatorUiToApi[trimmed];
    if (mapped != null) return mapped;
    if (trimmed.length <= maxDigitSeparatorLength) return trimmed;
    return trimmed.substring(0, maxDigitSeparatorLength);
  }

  /// Expands short API values for UI preview / currency screen.
  static String digitSeparatorFromApi(String apiValue) {
    final trimmed = apiValue.trim();
    if (trimmed.isEmpty) return trimmed;
    final mapped = _digitSeparatorApiToUi[trimmed.toLowerCase()] ??
        _digitSeparatorApiToUi[trimmed];
    if (mapped != null) return mapped;
    if (_digitSeparatorUiToApi.containsValue(trimmed)) {
      return _digitSeparatorApiToUi[trimmed] ?? trimmed;
    }
    return trimmed;
  }

  /// UI label like `30 minutes` → `00:30:00`.
  static String breakDurationToApi(String uiLabel) {
    final minutes =
        int.tryParse(uiLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}:00';
  }

  /// API time `hh:mm[:ss]` → closest UI dropdown label, e.g. `30 minutes`.
  static String? breakDurationLabelFromApi(
    String raw, {
    required List<String> dropdownOptions,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final mins = int.tryParse(parts[1]) ?? 0;
        final totalMinutes = hours * 60 + mins;
        if (totalMinutes > 0) {
          for (final option in dropdownOptions) {
            final optionMinutes = int.tryParse(
              option.replaceAll(RegExp(r'[^0-9]'), ''),
            );
            if (optionMinutes == totalMinutes) return option;
          }
          return '$totalMinutes minutes';
        }
      }
    }

    final lower = trimmed.toLowerCase();
    for (final option in dropdownOptions) {
      if (option.toLowerCase() == lower) return option;
    }
    final digits = int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
    if (digits != null) {
      for (final option in dropdownOptions) {
        final optionMinutes = int.tryParse(
          option.replaceAll(RegExp(r'[^0-9]'), ''),
        );
        if (optionMinutes == digits) return option;
      }
      return '$digits minutes';
    }
    return null;
  }
}
