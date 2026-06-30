import 'package:flutter/material.dart';
import 'package:red5/core/places/place_address.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/places_autocomplete_field.dart';

/// Layout variants for address forms across the app.
enum AppAddressLayout {
  /// Line1, Line2, Country dropdown, City|State, Pincode (vendor/client/contact/site).
  entityWithCountryDropdown,

  /// Line1, Line2, City|Zip, Country|State text fields (PO/bill/invoice).
  billing,

  /// Line1, Line2, Country, City, State|Pincode text fields (invite user).
  settings,

  /// Line1, Line2, City, State|Zip — no country (personal profile).
  profile,
}

typedef AppAddressLabelBuilder = Widget Function(
  String label, {
  bool required,
});

/// Standard address block with Google Places autocomplete on Address Line 1.
class AppAddressFields extends StatelessWidget {
  const AppAddressFields({
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    super.key,
    this.countryController,
    this.countryDropdownValue,
    this.countryDropdownOptions,
    this.onCountryDropdownChanged,
    this.onCountryResolved,
    this.layout = AppAddressLayout.billing,
    this.enabled = true,
    this.borderRadius = 8,
    this.line1Validator,
    this.cityValidator,
    this.stateValidator,
    this.postalCodeValidator,
    this.countryValidator,
    this.postalCodeLabel,
    this.labelBuilder,
    this.textStyle,
    this.hintStyle,
    this.dropdownDecoration,
    this.dropdownValueStyle,
    this.onPlaceSelected,
    this.line1Hint = 'Start typing an address',
    this.line2Hint = 'Address line 2',
    this.cityHint = 'City',
    this.stateHint = 'State',
    this.countryHint = 'Country',
    this.postalCodeHint = 'Pincode',
  });

  final TextEditingController line1;
  final TextEditingController line2;
  final TextEditingController city;
  final TextEditingController state;
  final TextEditingController postalCode;
  final TextEditingController? countryController;

  final String? countryDropdownValue;
  final List<String>? countryDropdownOptions;
  final ValueChanged<String>? onCountryDropdownChanged;
  final ValueChanged<String>? onCountryResolved;

  final AppAddressLayout layout;
  final bool enabled;
  final double borderRadius;
  final String? Function(String?)? line1Validator;
  final String? Function(String?)? cityValidator;
  final String? Function(String?)? stateValidator;
  final String? Function(String?)? postalCodeValidator;
  final String? Function(String?)? countryValidator;
  final String? postalCodeLabel;
  final AppAddressLabelBuilder? labelBuilder;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final InputDecoration? dropdownDecoration;
  final TextStyle? dropdownValueStyle;
  final ValueChanged<PlaceAddress>? onPlaceSelected;

  final String line1Hint;
  final String line2Hint;
  final String cityHint;
  final String stateHint;
  final String countryHint;
  final String postalCodeHint;

  static final _defaultLabelStyle = AppFonts.labelSmall(
    color: const Color(0xFF6B7280),
  ).copyWith(
    letterSpacing: 0.6,
    fontWeight: FontWeight.w600,
    fontSize: 11,
  );

  Widget _label(String text, {bool required = false}) {
    if (labelBuilder != null) {
      return labelBuilder!(text, required: required);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        required ? text.toUpperCase() : text.toUpperCase(),
        style: _defaultLabelStyle,
      ),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppTextField(
        controller: controller,
        hintText: hint,
        enabled: enabled,
        borderRadius: borderRadius,
        validator: validator,
        keyboardType: keyboardType,
        textStyle: textStyle,
        hintStyle: hintStyle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _line1Field() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PlacesAutocompleteField(
        controller: line1,
        hintText: line1Hint,
        enabled: enabled,
        borderRadius: borderRadius,
        validator: line1Validator,
        textStyle: textStyle,
        hintStyle: hintStyle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        onPlaceSelected: (place) {
          applyPlaceAddress(
            place: place,
            addressLine2: line2,
            city: city,
            state: state,
            postalCode: postalCode,
            country: countryController,
            onCountrySelected: (country) {
              if (country.trim().isEmpty) return;
              if (onCountryResolved != null) {
                onCountryResolved!(country);
              } else if (countryDropdownOptions != null &&
                  onCountryDropdownChanged != null) {
                final matched =
                    matchCountryOption(country, countryDropdownOptions!) ??
                        country;
                onCountryDropdownChanged!(matched);
              }
            },
          );
          onPlaceSelected?.call(place);
        },
      ),
    );
  }

  Widget _halfRow({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget? _countryDropdown() {
    final options = countryDropdownOptions;
    final value = countryDropdownValue;
    final onChanged = onCountryDropdownChanged;
    if (options == null || value == null || onChanged == null) return null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : options.first,
        items: options
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(
                  c,
                  style: dropdownValueStyle ??
                      AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            )
            .toList(),
        onChanged: enabled ? (v) { if (v != null) onChanged(v); } : null,
        isExpanded: true,
        decoration: dropdownDecoration ??
            const InputDecoration(
              filled: true,
              fillColor: AppColors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.textFieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.textFieldBorder),
              ),
            ),
      ),
    );
  }

  String get _zipLabel => postalCodeLabel ?? 'Pincode';

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      AppAddressLayout.entityWithCountryDropdown => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Address Line 1', required: line1Validator != null),
            _line1Field(),
            _label('Address Line 2'),
            _textField(line2, hint: line2Hint),
            _label('Country'),
            _countryDropdown() ?? const SizedBox.shrink(),
            _halfRow(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('City', required: cityValidator != null),
                  _textField(city, hint: cityHint, validator: cityValidator),
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('State / Province', required: stateValidator != null),
                  _textField(state, hint: stateHint, validator: stateValidator),
                ],
              ),
            ),
            _label(_zipLabel, required: postalCodeValidator != null),
            _textField(
              postalCode,
              hint: postalCodeHint,
              validator: postalCodeValidator,
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      AppAddressLayout.billing => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Address Line 1'),
            _line1Field(),
            _label('Address Line 2'),
            _textField(line2, hint: line2Hint),
            _halfRow(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('City'),
                  _textField(city, hint: cityHint),
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(_zipLabel == 'Pincode' ? 'Zip Code' : _zipLabel),
                  _textField(postalCode, hint: postalCodeHint),
                ],
              ),
            ),
            _halfRow(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Country'),
                  _textField(
                    countryController!,
                    hint: countryHint,
                  ),
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('State'),
                  _textField(state, hint: stateHint),
                ],
              ),
            ),
          ],
        ),
      AppAddressLayout.settings => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (labelBuilder != null)
              labelBuilder!('Address Line 1', required: true),
            _line1Field(),
            if (labelBuilder != null) labelBuilder!('Address Line 2'),
            _textField(line2, hint: line2Hint),
            if (countryController != null) ...[
              if (labelBuilder != null) labelBuilder!('Country', required: true),
              _textField(
                countryController!,
                hint: countryHint,
                validator: countryValidator,
              ),
            ],
            if (labelBuilder != null) labelBuilder!('City', required: true),
            _textField(city, hint: cityHint, validator: cityValidator),
            _halfRow(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (labelBuilder != null)
                    labelBuilder!('State', required: true),
                  _textField(state, hint: stateHint, validator: stateValidator),
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (labelBuilder != null)
                    labelBuilder!(_zipLabel, required: true),
                  _textField(
                    postalCode,
                    hint: postalCodeHint,
                    validator: postalCodeValidator,
                  ),
                ],
              ),
            ),
          ],
        ),
      AppAddressLayout.profile => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (labelBuilder != null) labelBuilder!('Address Line 1'),
            _line1Field(),
            if (labelBuilder != null) labelBuilder!('Address Line 2'),
            _textField(line2, hint: line2Hint),
            if (labelBuilder != null) labelBuilder!('City'),
            _textField(city, hint: cityHint),
            _halfRow(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (labelBuilder != null) labelBuilder!('State'),
                  _textField(state, hint: stateHint),
                ],
              ),
              right: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (labelBuilder != null) labelBuilder!('ZIP Code'),
                  _textField(postalCode, hint: postalCodeHint),
                ],
              ),
            ),
          ],
        ),
    };
  }
}
