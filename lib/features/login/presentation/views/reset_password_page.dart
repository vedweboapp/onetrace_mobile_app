import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/theme/app_screen_size.dart';
import 'package:red5/core/widgets/app_const_widget.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';

/// New password + confirmation after forgot-password OTP — dark header (slide 2)
/// and white sheet, with rules checklist and strength meter.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.email});

  final String? email;

  static const path = '/login/reset-password';
  static const name = 'resetPassword';

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  static const _mobileDark = Color(0xFF111111);
  static const _mobileSubtextGray = Color(0xFF666666);
  static const _mobileDotInactive = Color(0xFF757575);
  static const _strengthGreen = Color(0xFF16A34A);
  static const _strengthTrack = Color(0xFFE5E7EB);
  static const _onboardingSlideCount = 3;
  static const _resetOnboardingIndex = 1;

  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  late final PageController _onboardingPageController;
  int _onboardingPageIndex = _resetOnboardingIndex;

  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _isSubmitting = false;

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[!@#\$%^&*]');

  EdgeInsets _fieldScrollPadding(BuildContext context) {
    final kb = AppScreenSize.keyboardInsetBottomOf(context);
    return EdgeInsets.fromLTRB(12, 72, 12, kb + 140);
  }

  ({bool len, bool upper, bool lower, bool digit, bool special}) _rules(
    String p,
  ) {
    return (
      len: p.length >= 8,
      upper: _upper.hasMatch(p),
      lower: _lower.hasMatch(p),
      digit: _digit.hasMatch(p),
      special: _special.hasMatch(p),
    );
  }

  int _rulesMet(
    ({bool len, bool upper, bool lower, bool digit, bool special}) r,
  ) {
    return [r.len, r.upper, r.lower, r.digit, r.special]
        .where((e) => e)
        .length;
  }

  /// Bars lit (0–4) and label key for the meter.
  (int bars, String label) _strength(int met) {
    if (met >= 5) return (4, AppStrings.passwordStrengthStrong);
    if (met == 4) return (3, AppStrings.passwordStrengthGood);
    if (met == 3) return (2, AppStrings.passwordStrengthFair);
    if (met >= 1) return (1, AppStrings.passwordStrengthWeak);
    return (0, '');
  }

  (String title, String subtitle) _onboardingCopyForSlide(int index) {
    switch (index) {
      case 0:
        return (
          AppStrings.loginOnboardingTitle,
          AppStrings.loginOnboardingSubtitle.replaceAll('\n', ' '),
        );
      case 1:
        return (
          AppStrings.loginOnboarding2Title,
          AppStrings.loginOnboarding2Subtitle,
        );
      case 2:
        return (
          AppStrings.loginOnboarding3Title,
          AppStrings.loginOnboarding3Subtitle,
        );
      default:
        return ('', '');
    }
  }

  Widget _onboardingIcon(int index) {
    const size = 52.0;
    if (index == 1) {
      return Image.asset(
        AppImageString.mapSiteWorkPng,
        height: size,
        width: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.map_outlined,
          size: size,
          color: AppColors.white.withValues(alpha: 0.95),
        ),
      );
    }
    if (index == 2) {
      return Image.asset(
        AppImageString.editPenPng,
        height: size,
        width: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.edit_note,
          size: size,
          color: AppColors.white.withValues(alpha: 0.95),
        ),
      );
    }
    return Icon(
      Icons.map_outlined,
      size: size,
      color: AppColors.white.withValues(alpha: 0.95),
    );
  }

  Widget _onboardingSlide(int index, BuildContext context) {
    final (title, subtitle) = _onboardingCopyForSlide(index);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _onboardingIcon(index),
          vGap(20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.titleLarge(color: AppColors.white).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 25,
                  letterSpacing: -0.3,
                ),
          ),
          vGap(10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium(
                  color: AppColors.white.withValues(alpha: 0.65),
                ).copyWith(
                  height: 1.35,
                  fontSize: 18,
                ),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(BuildContext context, String text, bool met) {
    final fill = met ? _strengthGreen : const Color(0xFFE5E7EB);
    final border = met ? _strengthGreen : const Color(0xFF9CA3AF);
    final checkColor = met ? AppColors.white : const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: border, width: 1.2),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.check, size: 14, color: checkColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style:
                  AppFonts.bodyMedium(color: met ? _mobileDark : _mobileSubtextGray)
                      .copyWith(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: met ? FontWeight.w500 : FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _strengthMeter(BuildContext context, String password) {
    final r = _rules(password);
    final met = _rulesMet(r);
    final (bars, label) = _strength(met);
    final labelStrong = label == AppStrings.passwordStrengthStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < bars ? _strengthGreen : _strengthTrack,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            Text(
              label,
              style:
                  AppFonts.labelMedium(color: labelStrong ? _strengthGreen : _mobileSubtextGray)
                      .copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ruleRow(context, AppStrings.passwordRuleMinLength, r.len),
        _ruleRow(context, AppStrings.passwordRuleUppercase, r.upper),
        _ruleRow(context, AppStrings.passwordRuleLowercase, r.lower),
        _ruleRow(context, AppStrings.passwordRuleNumber, r.digit),
        _ruleRow(context, AppStrings.passwordRuleSpecial, r.special),
      ],
    );
  }

  bool _allRulesMet(String p) => _rulesMet(_rules(p)) == 5;

  String? _validateNewPassword(String? value) {
    final p = value ?? '';
    if (!_allRulesMet(p)) {
      return 'Password must meet all requirements';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if ((value ?? '') != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _onResetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(content: Text('Password has been reset. Sign in with your new password.')),
      );
      context.go('/login');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _sheetBody(
    BuildContext context, {
    required double bottomInset,
    required double keyboardInset,
  }) {
    final pw = _newPasswordController.text;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(22, 28, 22, 24 + bottomInset + keyboardInset),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.resetPasswordScreenTitle,
              style: AppFonts.headlineSmall(color: _mobileDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.resetPasswordScreenSubtitle,
              style:
                  AppFonts.bodyMedium(color: _mobileSubtextGray).copyWith(
                    fontSize: 14,
                    height: 1.35,
                  ),
            ),
            if (widget.email != null && widget.email!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.email!.trim(),
                style:
                    AppFonts.bodySmall(color: _mobileSubtextGray).copyWith(
                      fontSize: 13,
                    ),
              ),
            ],
            const SizedBox(height: 28),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _newPasswordFocusNode.requestFocus(),
              child: Text(
                AppStrings.resetPasswordNewLabel,
                style: AppFonts.labelLarge(color: _mobileDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _newPasswordController,
              focusNode: _newPasswordFocusNode,
              obscureText: _hideNew,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_confirmPasswordFocusNode),
              hintText: AppStrings.resetPasswordNewHint,
              scrollPadding: _fieldScrollPadding(context),
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hideNew = !_hideNew),
                icon: Icon(
                  _hideNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textFieldHint,
                  size: 22,
                ),
              ),
              validator: _validateNewPassword,
            ),
            const SizedBox(height: 16),
            _strengthMeter(context, pw),
            const SizedBox(height: 24),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _confirmPasswordFocusNode.requestFocus(),
              child: Text(
                AppStrings.resetPasswordConfirmLabel,
                style: AppFonts.labelLarge(color: _mobileDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              obscureText: _hideConfirm,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_onResetPassword()),
              hintText: AppStrings.loginPasswordHintShort,
              scrollPadding: _fieldScrollPadding(context),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _hideConfirm = !_hideConfirm),
                icon: Icon(
                  _hideConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textFieldHint,
                  size: 22,
                ),
              ),
              validator: _validateConfirm,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed:
                    _isSubmitting ? null : () => unawaited(_onResetPassword()),
                style: FilledButton.styleFrom(
                  backgroundColor: _mobileDark,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: _mobileDark.withValues(alpha: 0.45),
                  disabledForegroundColor:
                      AppColors.white.withValues(alpha: 0.7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: AppFonts.titleMedium().copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                ),
                child: Text(
                  _isSubmitting ? 'Saving…' : AppStrings.resetPasswordButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _onboardingPageController = PageController(initialPage: _resetOnboardingIndex);
  }

  @override
  void dispose() {
    _onboardingPageController.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = context.appScreenPadding.bottom;
    final keyboardInset = context.appKeyboardInsetBottom;
    final keyboardOpen = keyboardInset > 0;
    final headerFlex = keyboardOpen ? 10 : 36;
    final formFlex = keyboardOpen ? 90 : 64;

    return Scaffold(
      backgroundColor: _mobileDark,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            flex: headerFlex,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _onboardingPageController,
                        itemCount: _onboardingSlideCount,
                        onPageChanged: (i) {
                          setState(() => _onboardingPageIndex = i);
                        },
                        itemBuilder: (context, index) {
                          return _onboardingSlide(index, context);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_onboardingSlideCount, (i) {
                        final active = i == _onboardingPageIndex;
                        return GestureDetector(
                          onTap: () {
                            unawaited(
                              _onboardingPageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                              ),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: active ? 22 : 6,
                            height: active ? 7 : 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: active
                                  ? AppColors.white
                                  : _mobileDotInactive,
                            ),
                          ),
                        );
                      }),
                    ),
                    vGap(16),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: formFlex,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: ColoredBox(
                color: AppColors.white,
                child: SafeArea(
                  top: false,
                  child: _sheetBody(
                    context,
                    bottomInset: bottomInset,
                    keyboardInset: keyboardInset,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget resetPasswordPageBuilder(BuildContext context, GoRouterState state) {
  String? email;
  final q = state.uri.queryParameters['email'];
  if (q != null && q.trim().isNotEmpty) {
    email = q.trim();
  }
  return ResetPasswordPage(email: email);
}
