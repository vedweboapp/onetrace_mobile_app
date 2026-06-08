import 'package:country_code_picker/country_code_picker.dart';

/// Parsed phone: country dial code + national digits (no spaces).
class ParsedPhoneNumber {
  const ParsedPhoneNumber({
    required this.country,
    required this.nationalDigits,
  });

  final CountryCode country;
  final String nationalDigits;
}

/// Helpers for [country_code_picker] + API storage as E.164-style strings.
abstract final class PhoneNumberUtils {
  PhoneNumberUtils._();

  static const List<String> favoriteCountryCodes = <String>[
    'US',
    'IN',
    'GB',
    'CA',
    'AU',
  ];

  static CountryCode get defaultCountry =>
      CountryCode.fromCountryCode('US');

  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  /// Splits a stored phone into country + national number for the text field.
  static ParsedPhoneNumber parse(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return ParsedPhoneNumber(
        country: defaultCountry,
        nationalDigits: '',
      );
    }

    final normalized = trimmed.startsWith('+')
        ? trimmed
        : '+$trimmed';

    final byDial = _matchByDialCode(normalized);
    if (byDial != null) return byDial;

    final digits = digitsOnly(trimmed);
    return ParsedPhoneNumber(
      country: defaultCountry,
      nationalDigits: digits,
    );
  }

  static ParsedPhoneNumber? _matchByDialCode(String withPlus) {
    final sorted = List<Map<String, String>>.from(codes)
      ..sort(
        (a, b) => (b['dial_code'] ?? '').length.compareTo(
              (a['dial_code'] ?? '').length,
            ),
      );

    for (final entry in sorted) {
      final dial = entry['dial_code'];
      final iso = entry['code'];
      if (dial == null || dial.isEmpty || iso == null || iso.isEmpty) {
        continue;
      }
      if (!withPlus.startsWith(dial)) continue;
      final national = digitsOnly(withPlus.substring(dial.length));
      return ParsedPhoneNumber(
        country: CountryCode.fromCountryCode(iso),
        nationalDigits: national,
      );
    }
    return null;
  }

  /// Full number for API / storage, e.g. `+15551234567`.
  static String formatFull(CountryCode country, String national) {
    final dial = country.dialCode ?? '';
    final digits = digitsOnly(national);
    if (digits.isEmpty) return '';
    return '$dial$digits';
  }

  static String? validateNational({
    required String? national,
    int minDigits = 7,
    int maxDigits = 15,
    String emptyMessage = 'Phone is required',
    String invalidMessage = 'Enter a valid phone number',
  }) {
    final digits = digitsOnly(national ?? '');
    if (digits.isEmpty) return emptyMessage;
    if (digits.length < minDigits || digits.length > maxDigits) {
      return invalidMessage;
    }
    return null;
  }
}
