import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/theme/app_screen_size.dart';
import 'package:red5/core/widgets/app_const_widget.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/login/presentation/views/reset_password_page.dart';

/// How [OtpVerifyPage] was opened — drives titles, primary/secondary actions, and footer.
enum OtpVerifyFlow {
  /// After “Sign in with OTP” / send code from login.
  signIn,

  /// After forgot password → send reset OTP.
  forgotPassword,
}

/// Query value for [OtpVerifyPage] when opened from the forgot-password flow (`?flow=…`).
const String otpVerifyFlowForgotPasswordQueryValue = 'forgot';

/// Full-screen mobile OTP entry (code verification) with the same dark header /
/// white sheet layout as [LoginPage].
class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({
    super.key,
    this.email,
    this.flow = OtpVerifyFlow.signIn,
  });

  /// Optional email shown for context; may be passed via [GoRouter] `extra` or query `?email=`.
  final String? email;

  final OtpVerifyFlow flow;

  static const path = '/login/otp';
  static const name = 'loginOtp';

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  bool get _isForgotPasswordFlow =>
      widget.flow == OtpVerifyFlow.forgotPassword;

  static const _mobileDark = Color(0xFF111111);
  static const _mobileSubtextGray = Color(0xFF666666);
  static const _mobileBorder = Color(0xFFE0E0E0);
  static const _mobileDotInactive = Color(0xFF757575);
  static const _onboardingSlideCount = 3;

  late final PageController _onboardingPageController;
  int _onboardingPageIndex = 0;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  Timer? _resendTimer;
  int _resendSecondsLeft = 30;
  bool _isSubmitting = false;

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

  Widget _onboardingMapIcon(int index) {
    const size = 52.0;
    if (index == 0 && _isForgotPasswordFlow) {
      return Image.asset(
        AppImageString.siteWorkPng,
        height: size,
        width: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.layers_outlined,
          size: size,
          color: AppColors.white.withValues(alpha: 0.95),
        ),
      );
    }
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
          _onboardingMapIcon(index),
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

  @override
  void initState() {
    super.initState();
    _onboardingPageController = PageController();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_resendSecondsLeft <= 1) {
        _resendTimer?.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  String _otpCode() => _otpControllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _otpControllers[index].clear();
      setState(() {});
      return;
    }
    final char = digits.substring(0, 1);
    _otpControllers[index].text = char;
    _otpControllers[index].selection =
        const TextSelection.collapsed(offset: 1);
    if (index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
    setState(() {});
  }

  KeyEventResult _onOtpKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
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

  Future<void> _onSubmitOtp() async {
    final code = _otpCode();
    if (code.length != 6) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      if (_isForgotPasswordFlow) {
        final email = widget.email?.trim() ?? '';
        final uri = email.isEmpty
            ? Uri(path: ResetPasswordPage.path)
            : Uri(
                path: ResetPasswordPage.path,
                queryParameters: <String, String>{'email': email},
              );
        context.pushReplacement(uri.toString());
        return;
      }
      context.showTopSnackBar(
        SnackBar(content: Text('Code entered: $code')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onResendTap() {
    if (_resendSecondsLeft > 0) return;
    _startResendTimer();
    if (!mounted) return;
    context.showTopSnackBar(
      SnackBar(
        content: Text(
          widget.email != null && widget.email!.isNotEmpty
              ? 'A new code was sent to ${widget.email}'
              : 'If OTP is enabled, a new code will be sent.',
        ),
      ),
    );
  }

  void _onSecondaryAction() {
    if (_isForgotPasswordFlow) {
      context.go('/login');
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      // Keep in sync with [LoginPage.path] (`/login`).
      context.go('/login');
    }
  }

  Widget _otpField(BuildContext context, int index) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Focus(
          onKeyEvent: (node, event) => _onOtpKey(index, event),
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction:
                index < 5 ? TextInputAction.next : TextInputAction.done,
            style: AppFonts.headlineSmall(color: _mobileDark).copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _mobileBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _mobileBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _mobileDark, width: 1.5),
              ),
            ),
            onChanged: (v) => _onOtpChanged(index, v),
          ),
        ),
      ),
    );
  }

  Widget _resendRow(BuildContext context) {
    final canResend = _resendSecondsLeft == 0;
    final mm = (_resendSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (_resendSecondsLeft % 60).toString().padLeft(2, '0');
    final countdown = '$mm:$ss';

    return Center(
      child: Text.rich(
        TextSpan(
          style: AppFonts.bodyMedium(color: _mobileSubtextGray).copyWith(
                fontSize: 14,
                height: 1.35,
              ),
          children: [
            TextSpan(text: AppStrings.otpResendLead),
            TextSpan(
              text: canResend
                  ? AppStrings.otpResendCta
                  : '${AppStrings.otpResendInPrefix}$countdown',
              style: AppFonts.bodyMedium(color: _mobileDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          Text(
            '${AppStrings.loginNoAccountQuestion} ',
            style: AppFonts.bodyMedium(color: _mobileSubtextGray).copyWith(
                  fontSize: 14,
                ),
          ),
          GestureDetector(
            onTap: () {},
            child: Text(
              AppStrings.loginRequestAccessArrow,
              style: AppFonts.bodyMedium(color: _mobileDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetBody(
    BuildContext context, {
    required double bottomInset,
    required double keyboardInset,
  }) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(22, 28, 22, 24 + bottomInset + keyboardInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isForgotPasswordFlow
                ? AppStrings.otpForgotPasswordVerifyTitle
                : AppStrings.otpVerifyTitle,
            style: AppFonts.headlineSmall(color: _mobileDark).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.otpVerifySubtitle,
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
            onTap: () => _otpFocusNodes.first.requestFocus(),
            child: Text(
              AppStrings.otpLabel,
              style: AppFonts.labelLarge(color: _mobileDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: List.generate(6, (i) => _otpField(context, i))),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _onResendTap,
            behavior: HitTestBehavior.opaque,
            child: _resendRow(context),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isSubmitting ? null : () => unawaited(_onSubmitOtp()),
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
                _isSubmitting
                    ? (_isForgotPasswordFlow ? 'Verifying…' : 'Signing in…')
                    : (_isForgotPasswordFlow
                        ? AppStrings.otpVerifyOtpButton
                        : AppStrings.loginSignInLower),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _onSecondaryAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: _mobileDark,
                side: const BorderSide(color: _mobileBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: AppFonts.titleMedium().copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
              ),
              child: Text(
                _isForgotPasswordFlow
                    ? AppStrings.forgotPasswordBackToLogin
                    : AppStrings.loginSignInWithPassword,
              ),
            ),
          ),
          if (!_isForgotPasswordFlow) ...[
            const SizedBox(height: 28),
            _footer(context),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _onboardingPageController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
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

/// Builds [OtpVerifyPage] from router [state] (`extra` as [String] email or `?email=`).
///
/// Forgot-password flow: `?flow=forgot` (see [otpVerifyFlowForgotPasswordQueryValue]).
Widget otpVerifyPageBuilder(BuildContext context, GoRouterState state) {
  String? email;
  final extra = state.extra;
  if (extra is String && extra.trim().isNotEmpty) {
    email = extra.trim();
  } else {
    final q = state.uri.queryParameters['email'];
    if (q != null && q.trim().isNotEmpty) {
      email = q.trim();
    }
  }
  final flowParam = state.uri.queryParameters['flow'];
  final flow = flowParam == otpVerifyFlowForgotPasswordQueryValue
      ? OtpVerifyFlow.forgotPassword
      : OtpVerifyFlow.signIn;
  return OtpVerifyPage(email: email, flow: flow);
}
