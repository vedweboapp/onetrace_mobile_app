import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/phone_number_utils.dart';

/// Outlined phone field with flag + dial-code picker prefix ([country_code_picker]).
///
/// [controller] holds the **national** number (digits only). Use [PhoneNumberUtils.formatFull]
/// with [onCountryChanged] when saving.
class AppPhoneTextField extends StatefulWidget {
  const AppPhoneTextField({
    required this.controller,
    super.key,
    this.hintText = 'Phone number',
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    this.dense = false,
    this.borderRadius = AppPhoneTextField.defaultBorderRadius,
    this.fillColor,
    this.hintStyle,
    this.textStyle,
    this.suffixIcon,
    this.initialCountry,
    this.onCountryChanged,
    this.showCountryPicker = true,
    this.scrollPadding,
  });

  static const double defaultBorderRadius = 10;

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final bool dense;
  final double borderRadius;
  final Color? fillColor;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;
  final Widget? suffixIcon;
  final CountryCode? initialCountry;
  final ValueChanged<CountryCode>? onCountryChanged;
  final bool showCountryPicker;
  final EdgeInsets? scrollPadding;

  @override
  State<AppPhoneTextField> createState() => _AppPhoneTextFieldState();
}

class _AppPhoneTextFieldState extends State<AppPhoneTextField> {
  late CountryCode _selectedCountry;
  bool _parsedInitial = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry ?? PhoneNumberUtils.defaultCountry;
    _applyInitialParse();
  }

  @override
  void didUpdateWidget(AppPhoneTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCountry != null &&
        widget.initialCountry != oldWidget.initialCountry) {
      _selectedCountry = widget.initialCountry!;
    }
  }

  void _applyInitialParse() {
    if (_parsedInitial) return;
    _parsedInitial = true;
    final parsed = PhoneNumberUtils.parse(widget.controller.text);
    _selectedCountry = widget.initialCountry ?? parsed.country;
    if (parsed.nationalDigits.isNotEmpty) {
      widget.controller.text = parsed.nationalDigits;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCountryChanged?.call(_selectedCountry);
    });
  }

  void _onCountryChanged(CountryCode country) {
    setState(() => _selectedCountry = country);
    widget.onCountryChanged?.call(country);
  }

  OutlineInputBorder _outlineBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _countryPrefix(TextStyle dialStyle, TextStyle hintTextStyle) {
    if (widget.showCountryPicker && widget.enabled) {
      return CountryCodePicker(
        onChanged: _onCountryChanged,
        initialSelection: _selectedCountry.code,
        favorite: PhoneNumberUtils.favoriteCountryCodes,
        showCountryOnly: false,
        showOnlyCountryWhenClosed: false,
        alignLeft: false,
        showFlag: true,
        showFlagDialog: true,
        showDropDownButton: true,
        flagWidth: widget.dense ? 20 : 24,
        padding: EdgeInsets.only(left: widget.dense ? 6 : 8, right: 2),
        textStyle: dialStyle,
        dialogTextStyle: AppFonts.bodyMedium(
          color: AppColors.textFieldForeground,
        ).copyWith(fontSize: 15),
        searchDecoration: InputDecoration(
          hintText: 'Search country',
          hintStyle: hintTextStyle,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textFieldHint,
            size: 22,
          ),
          filled: true,
          fillColor: AppColors.surfaceHigh,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: _outlineBorder(AppColors.textFieldBorder),
          enabledBorder: _outlineBorder(AppColors.textFieldBorder),
          focusedBorder: _outlineBorder(
            AppColors.textFieldFocusBorder,
            width: 1.2,
          ),
        ),
        dialogBackgroundColor: AppColors.white,
        barrierColor: AppColors.sheetBarrier,
        dialogSize: Size(
          MediaQuery.sizeOf(context).width * 0.92,
          MediaQuery.sizeOf(context).height * 0.72,
        ),
        boxDecoration: const BoxDecoration(color: Colors.transparent),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: widget.dense ? 10 : 12, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedCountry.flagUri != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.asset(
                _selectedCountry.flagUri!,
                package: 'country_code_picker',
                width: widget.dense ? 22 : 26,
                height: widget.dense ? 16 : 18,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 8),
          Text(_selectedCountry.dialCode ?? '', style: dialStyle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseText = AppFonts.bodyMedium();
    final fieldText = widget.textStyle ??
        baseText.copyWith(
          color: AppColors.textFieldForeground,
          fontWeight: FontWeight.w500,
          fontSize: widget.dense ? 13 : 15,
        );
    final hintTextStyle = widget.hintStyle ??
        baseText.copyWith(
          color: AppColors.textFieldHint,
          fontWeight: FontWeight.w400,
          fontSize: widget.dense ? 13 : 15,
        );
    final dialStyle = baseText.copyWith(
      color: AppColors.textFieldForeground,
      fontWeight: FontWeight.w600,
      fontSize: widget.dense ? 13 : 15,
    );

    final verticalPad = widget.dense ? 14.0 : 16.0;

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      scrollPadding: widget.scrollPadding ??
          const EdgeInsets.fromLTRB(16, 24, 16, 120),
      cursorColor: AppColors.textFieldFocusBorder,
      style: fieldText,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: hintTextStyle,
        isDense: widget.dense,
        filled: true,
        fillColor: widget.fillColor ?? AppColors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: verticalPad,
        ),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _countryPrefix(dialStyle, hintTextStyle),
            Container(
              width: 1,
              height: widget.dense ? 22 : 28,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: AppColors.textFieldBorder,
            ),
          ],
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.suffixIcon,
        border: _outlineBorder(AppColors.textFieldBorder),
        enabledBorder: _outlineBorder(AppColors.textFieldBorder),
        focusedBorder: _outlineBorder(
          AppColors.textFieldFocusBorder,
          width: 1.2,
        ),
        disabledBorder: _outlineBorder(
          AppColors.textFieldBorder.withValues(alpha: 0.5),
        ),
        errorBorder: _outlineBorder(AppColors.error, width: 1.1),
        focusedErrorBorder: _outlineBorder(AppColors.error, width: 1.2),
      ),
    );
  }
}
