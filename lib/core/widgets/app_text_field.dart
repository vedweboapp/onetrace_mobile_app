import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Single outlined field style (aligned with login): white fill, `#E0E0E0` border,
/// `#111111` focus ring, `#9E9E9E` hints. Use [validator] for [TextFormField];
/// omit it for a plain [TextField] (e.g. dialogs without a [Form]).
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.hintText,
    super.key,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.textAlign = TextAlign.start,
    this.textStyle,
    this.hintStyle,
    this.contentPadding,
    this.fillColor,
    this.borderRadius = 10,
    this.dense = false,
    this.scrollPadding,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final bool enabled;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final TextAlign textAlign;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final double borderRadius;
  final bool dense;
  /// Extra space used when scrolling the field into view above the keyboard.
  final EdgeInsets? scrollPadding;

  static const double defaultBorderRadius = 10;

  InputDecoration _buildDecoration(BuildContext context) {
    final base = AppFonts.bodyMedium();
    final effectiveHint = hintStyle ??
        base.copyWith(
          color: AppColors.textFieldHint,
          fontWeight: FontWeight.w400,
          fontSize: dense ? 13 : 15,
        );

    return InputDecoration(
      hintText: hintText,
      hintStyle: effectiveHint,
      isDense: dense,
      filled: true,
      fillColor: fillColor ?? AppColors.white,
      contentPadding: contentPadding ??
          (dense
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: AppColors.textFieldHint,
              size: dense ? 18 : 22,
            ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: AppColors.textFieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: AppColors.textFieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: AppColors.textFieldFocusBorder, width: 1.2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: AppColors.textFieldBorder.withValues(alpha: 0.5)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: AppColors.error, width: 1.1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
    );
  }

  TextStyle _effectiveTextStyle(BuildContext context) {
    if (textStyle != null) return textStyle!;
    final base = AppFonts.bodyMedium();
    return base.copyWith(
      color: AppColors.textFieldForeground,
      fontWeight: FontWeight.w500,
      fontSize: dense ? 13 : 15,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = _buildDecoration(context);

    final effectiveScrollPadding = scrollPadding ??
        const EdgeInsets.fromLTRB(16, 24, 16, 120);

    if (validator != null) {
      return TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged,
        enabled: enabled,
        focusNode: focusNode,
        maxLines: obscureText ? 1 : maxLines,
        minLines: minLines,
        readOnly: readOnly,
        textAlign: textAlign,
        scrollPadding: effectiveScrollPadding,
        cursorColor: AppColors.textFieldFocusBorder,
        style: _effectiveTextStyle(context),
        decoration: inputDecoration,
      );
    }

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      focusNode: focusNode,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      readOnly: readOnly,
      textAlign: textAlign,
      scrollPadding: effectiveScrollPadding,
      cursorColor: AppColors.textFieldFocusBorder,
      style: _effectiveTextStyle(context),
      decoration: inputDecoration,
    );
  }
}
