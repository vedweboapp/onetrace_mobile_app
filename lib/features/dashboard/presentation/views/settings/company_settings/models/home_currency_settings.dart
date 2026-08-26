part of '../company_settings.dart';

enum CurrencyFormatMode { symbol, code }

/// Home currency + display format (Change Home Currency screen).
class HomeCurrencySettings {
  const HomeCurrencySettings({
    required this.homeCurrency,
    this.formatMode = CurrencyFormatMode.symbol,
    this.symbol = 'â‚¹',
    this.symbolPosition = 'Before Value',
    this.digitSeparator = '12,34,567.89',
    this.decimalPlaces = 2,
  });

  final String homeCurrency;
  final CurrencyFormatMode formatMode;
  final String symbol;
  final String symbolPosition;
  final String digitSeparator;
  final int decimalPlaces;

  factory HomeCurrencySettings.defaults() {
    return const HomeCurrencySettings(homeCurrency: 'Indian Rupee - INR');
  }

  String get currencyCode {
    final parts = homeCurrency.split(' - ');
    if (parts.length >= 2) return parts.last.trim();
    return 'INR';
  }

  String get displayUnit =>
      formatMode == CurrencyFormatMode.symbol ? symbol : currencyCode;

  bool get symbolBefore => symbolPosition == 'Before Value';

  String formatPreview([double value = 1234567.89]) {
    final amount = formatAmount(value);
    if (symbolBefore) return '$displayUnit $amount';
    return '$amount $displayUnit';
  }

  String formatAmount(double value) {
    final rounded =
        (value * math.pow(10, decimalPlaces)).round() /
        math.pow(10, decimalPlaces);
    final fixed = rounded.toStringAsFixed(decimalPlaces);
    final parts = fixed.split('.');
    final grouped = _groupInteger(int.parse(parts[0]), digitSeparator);
    if (decimalPlaces == 0) return grouped;
    final decSep =
        digitSeparator.contains(',') &&
            digitSeparator.indexOf(',') > digitSeparator.indexOf('.')
        ? ','
        : '.';
    return '$grouped$decSep${parts[1]}';
  }

  static String defaultSymbolFor(String homeCurrency) {
    if (homeCurrency.contains('INR')) return 'â‚¹';
    if (homeCurrency.contains('USD')) return '\$';
    if (homeCurrency.contains('EUR')) return 'â‚¬';
    if (homeCurrency.contains('GBP')) return 'Â£';
    return 'â‚¹';
  }

  static String defaultSeparatorFor(String homeCurrency) {
    if (homeCurrency.contains('INR')) return '12,34,567.89';
    if (homeCurrency.contains('EUR')) return '1.234.567,89';
    return '1,234,567.89';
  }

  static String _groupInteger(int value, String pattern) {
    if (pattern.startsWith('12,34')) {
      return _indianGrouping(value);
    }
    if (pattern.contains('.') && pattern.contains(',')) {
      return _europeanGrouping(value);
    }
    return _usGrouping(value);
  }

  static String _indianGrouping(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final chunks = <String>[];
    while (rest.length > 2) {
      chunks.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) chunks.insert(0, rest);
    return '${chunks.join(',')},$last3';
  }

  static String _usGrouping(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      if (count == 3) {
        buf.write(',');
        count = 0;
      }
      buf.write(s[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }

  static String _europeanGrouping(int n) => _usGrouping(n).replaceAll(',', '.');
}

