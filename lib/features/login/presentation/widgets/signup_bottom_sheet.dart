import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';

/// Opens the create-account bottom sheet from the login screen.
Future<void> showSignupBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const SignupBottomSheet(),
  );
}

class SignupBottomSheet extends ConsumerStatefulWidget {
  const SignupBottomSheet({super.key});

  @override
  ConsumerState<SignupBottomSheet> createState() => _SignupBottomSheetState();
}

class _SignupBottomSheetState extends ConsumerState<SignupBottomSheet> {
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF666666);
  static const _border = Color(0xFFE0E0E0);
  static const _otpLength = 6;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  bool _hidePassword = true;
  bool _isSubmitting = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  bool _emailVerified = false;

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(
      _otpLength,
      (_) => TextEditingController(),
    );
    _otpFocusNodes = List.generate(_otpLength, (_) => FocusNode());
    _emailController.addListener(_onEmailTextChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailTextChanged);
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  TextStyle get _labelStyle => AppFonts.labelLarge(color: _ink).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      );

  String _otpCode() => _otpControllers.map((c) => c.text).join();

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
  }

  void _resetEmailVerification() {
    setState(() {
      _otpSent = false;
      _emailVerified = false;
      _isVerifyingOtp = false;
    });
    _clearOtpFields();
  }

  void _onEmailTextChanged() {
    if (!_otpSent && !_emailVerified) return;
    _resetEmailVerification();
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: _labelStyle),
    );
  }

  Widget _emailLabelRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(AppStrings.signupEmailLabel, style: _labelStyle),
          const Spacer(),
          if (_emailVerified)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Color(0xFF12A150),
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.signupEmailVerified,
                  style: AppFonts.labelLarge(
                    color: const Color(0xFF12A150),
                  ).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: _isSendingOtp || _otpSent ? null : _onVerifyEmail,
              behavior: HitTestBehavior.opaque,
              child: _isSendingOtp
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _ink.withValues(alpha: 0.6),
                      ),
                    )
                  : Text(
                      AppStrings.signupVerify,
                      style: AppFonts.labelLarge(color: _muted).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _onVerifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      context.showTopSnackBar(
        const SnackBar(content: Text(AppStrings.signupVerifyEmailInvalid)),
      );
      return;
    }
    if (_isSendingOtp) return;

    setState(() => _isSendingOtp = true);
    try {
      final client = ref.read(authApiClientProvider);
      await client.sendOtp(
        email: email,
        extraFields: const {
          'purpose': AuthApiClient.otpPurposeEmailVerify,
        },
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _emailVerified = false;
        _isSendingOtp = false;
      });
      _clearOtpFields();
      _otpFocusNodes.first.requestFocus();
      context.showTopSnackBar(
        SnackBar(content: Text(AppStrings.signupVerifySentTo(email))),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromDioException(
              e,
              genericFallback: AppStrings.apiErrorSendOtp,
            ),
          ),
        ),
      );
    }
  }

  void _onOtpChanged(int index, String raw) {
    final char = raw.isEmpty ? '' : raw.characters.last;
    if (char.isEmpty) {
      _otpControllers[index].clear();
      setState(() {});
      return;
    }
    _otpControllers[index].text = char;
    _otpControllers[index].selection =
        const TextSelection.collapsed(offset: 1);
    if (index < _otpLength - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
    setState(() {});
    if (_otpCode().length == _otpLength &&
        !_isVerifyingOtp &&
        !_emailVerified &&
        _otpSent) {
      unawaited(_verifyEmailOtp());
    }
  }

  Future<void> _verifyEmailOtp() async {
    final email = _emailController.text.trim();
    final code = _otpCode();
    if (email.isEmpty || code.length != _otpLength) return;
    if (_isVerifyingOtp || _emailVerified) return;

    setState(() => _isVerifyingOtp = true);
    try {
      final client = ref.read(authApiClientProvider);
      await client.verifyOtp(
        email: email,
        otp: code,
        extraFields: const {
          'purpose': AuthApiClient.otpPurposeEmailVerify,
        },
      );
      if (!mounted) return;
      setState(() {
        _emailVerified = true;
        _otpSent = false;
        _isVerifyingOtp = false;
      });
      _clearOtpFields();
      FocusScope.of(context).unfocus();
      context.showTopSnackBar(
        const SnackBar(
          content: Text(AppStrings.signupEmailVerifiedMessage),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromDioException(
              e,
              genericFallback: AppStrings.apiErrorVerifyOtp,
            ),
          ),
        ),
      );
    }
  }

  KeyEventResult _onOtpKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_otpControllers[index].text.isNotEmpty) {
      return KeyEventResult.ignored;
    }
    if (index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
      _otpControllers[index - 1].clear();
      setState(() {});
    }
    return KeyEventResult.handled;
  }

  Future<void> _onSignUp() async {
    if (!_emailVerified) {
      context.showTopSnackBar(
        const SnackBar(content: Text(AppStrings.signupEmailNotVerified)),
      );
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_emailVerified) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(authApiClientProvider);
      await client.orgUserSignup(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showTopSnackBar(
        const SnackBar(content: Text(AppStrings.signupSuccessMessage)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromDioException(
              e,
              genericFallback: AppStrings.apiErrorSignup,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _otpField(int index) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(
          left: index == 0 ? 0 : 4,
          right: index == _otpLength - 1 ? 0 : 4,
        ),
        child: Focus(
          onKeyEvent: (node, event) => _onOtpKey(index, event),
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction:
                index < _otpLength - 1 ? TextInputAction.next : TextInputAction.done,
            style: AppFonts.headlineSmall(color: _ink).copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _ink, width: 1.5),
              ),
            ),
            onChanged: (v) => _onOtpChanged(index, v),
            enabled: !_isVerifyingOtp,
          ),
        ),
      ),
    );
  }

  Widget? _otpSection() {
    if (!_otpSent || _emailVerified) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(AppStrings.otpLabel),
        Row(
          children: List.generate(_otpLength, (i) => _otpField(i)),
        ),
        if (_isVerifyingOtp) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _ink.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.signupVerifyingOtp,
                style: AppFonts.bodySmall(color: _muted).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _loginFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              AppStrings.signupAlreadyHaveAccount,
              style: AppFonts.bodyMedium(color: _muted).copyWith(fontSize: 14),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                AppStrings.signupLogIn,
                style: AppFonts.bodyMedium(color: _ink).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const Expanded(child: Divider(color: _border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              AppStrings.signupOrSignUpWith,
              style: AppFonts.labelMedium(color: _muted).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const Expanded(child: Divider(color: _border, height: 1)),
        ],
      ),
    );
  }

  Widget _socialIcon(String assetPath) {
    return Image.asset(
      assetPath,
      width: 24,
      height: 24,
      fit: BoxFit.contain,
    );
  }

  Widget _socialButton({
    required Widget child,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            backgroundColor: AppColors.white,
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
            padding: EdgeInsets.zero,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppStrings.signupCreateAccountTitle,
                          style: AppFonts.headlineSmall(color: _ink).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _fieldLabel(AppStrings.signupFirstName),
                        AppTextField(
                          controller: _firstNameController,
                          hintText: '',
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return AppStrings.signupFieldRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _fieldLabel(AppStrings.signupMiddleName),
                        AppTextField(
                          controller: _middleNameController,
                          hintText: '',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 18),
                        _fieldLabel(AppStrings.signupLastName),
                        AppTextField(
                          controller: _lastNameController,
                          hintText: '',
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return AppStrings.signupFieldRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _emailLabelRow(),
                        AppTextField(
                          controller: _emailController,
                          hintText: AppStrings.signupEmailHint,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline,
                          textInputAction: TextInputAction.next,
                          readOnly: _emailVerified,
                          enabled: !_emailVerified,
                          validator: (v) {
                            final email = (v ?? '').trim();
                            if (email.isEmpty || !email.contains('@')) {
                              return AppStrings.signupEmailInvalid;
                            }
                            return null;
                          },
                        ),
                        if (_otpSection() != null) _otpSection()!,
                        _fieldLabel(AppStrings.signupPhoneLabel),
                        AppTextField(
                          controller: _phoneController,
                          hintText: AppStrings.signupPhoneHint,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return AppStrings.signupFieldRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _fieldLabel(AppStrings.passwordLabel),
                        AppTextField(
                          controller: _passwordController,
                          hintText: '',
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textFieldHint,
                              size: 22,
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '').length < 6) {
                              return AppStrings.signupPasswordMinLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : () => _onSignUp(),
                            style: FilledButton.styleFrom(
                              backgroundColor: _ink,
                              foregroundColor: AppColors.white,
                              disabledBackgroundColor:
                                  _ink.withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                              textStyle: AppFonts.titleMedium().copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.8,
                              ),
                            ),
                            child: Text(
                              _isSubmitting
                                  ? AppStrings.signupSubmitting
                                  : AppStrings.signupButton,
                            ),
                          ),
                        ),
                        _orDivider(),
                        Row(
                          children: [
                            _socialButton(
                              onPressed: () {
                                context.showTopSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      AppStrings.signupGoogleComingSoon,
                                    ),
                                  ),
                                );
                              },
                              child: _socialIcon(AppImageString.googlePng),
                            ),
                            const SizedBox(width: 12),
                            _socialButton(
                              onPressed: () {
                                context.showTopSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      AppStrings.signupMicrosoftComingSoon,
                                    ),
                                  ),
                                );
                              },
                              child: _socialIcon(AppImageString.microsoftPng),
                            ),
                            const SizedBox(width: 12),
                            _socialButton(
                              onPressed: () {
                                context.showTopSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      AppStrings.signupFacebookComingSoon,
                                    ),
                                  ),
                                );
                              },
                              child: _socialIcon(AppImageString.facebookPng),
                            ),
                          ],
                        ),
                        _loginFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
