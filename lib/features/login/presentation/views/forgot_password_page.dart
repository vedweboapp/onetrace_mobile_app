import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/theme/app_screen_size.dart';
import 'package:red5/core/widgets/app_const_widget.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/login/presentation/views/otp_verify_page.dart';

/// Request password reset email / OTP — same dark header + white sheet layout as login.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  static const path = '/login/forgot-password';
  static const name = 'forgotPassword';

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  static const _mobileDark = Color(0xFF111111);
  static const _mobileSubtextGray = Color(0xFF666666);
  static const _mobileBorder = Color(0xFFE0E0E0);
  static const _mobileDotInactive = Color(0xFF757575);
  static const _onboardingSlideCount = 3;
  static const _forgotPasswordOnboardingIndex = 2;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();

  late final PageController _onboardingPageController;
  int _onboardingPageIndex = _forgotPasswordOnboardingIndex;

  bool _isSending = false;

  EdgeInsets _fieldScrollPadding(BuildContext context) {
    final kb = AppScreenSize.keyboardInsetBottomOf(context);
    return EdgeInsets.fromLTRB(12, 72, 12, kb + 140);
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
          AppStrings.forgotPasswordOnboardingTitle,
          AppStrings.forgotPasswordOnboardingSubtitle,
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

  @override
  void initState() {
    super.initState();
    _onboardingPageController = PageController(
      initialPage: _forgotPasswordOnboardingIndex,
    );
  }

  Future<void> _onSendResetOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSending) return;
    final email = _emailController.text.trim();
    setState(() => _isSending = true);
    try {
      final client = ref.read(authApiClientProvider);
      await client.sendOtp(
        email: email,
        extraFields: const {'purpose': 'forgot'},
      );
      if (!mounted) return;
      context.push(
        Uri(
          path: OtpVerifyPage.path,
          queryParameters: {
            'email': email,
            'flow': otpVerifyFlowForgotPasswordQueryValue,
          },
        ).toString(),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromDioException(
              e,
              genericFallback: AppStrings.apiErrorForgotPassword,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onBackToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Widget _sheetBody(
    BuildContext context, {
    required double bottomInset,
    required double keyboardInset,
  }) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(22, 28, 22, 24 + bottomInset + keyboardInset),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.forgotPasswordScreenTitle,
              style: AppFonts.headlineSmall(color: _mobileDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.forgotPasswordScreenSubtitle,
              style:
                  AppFonts.bodyMedium(color: _mobileSubtextGray).copyWith(
                    fontSize: 14,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _emailFocusNode.requestFocus(),
              child: Text(
                AppStrings.emailLabel,
                style: AppFonts.labelLarge(color: _mobileDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_onSendResetOtp()),
              hintText: AppStrings.loginEmailHintRegistered,
              scrollPadding: _fieldScrollPadding(context),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSending ? null : () => unawaited(_onSendResetOtp()),
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
                  _isSending ? 'Sending…' : AppStrings.forgotPasswordSendResetOtp,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _onBackToLogin,
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
                child: const Text(AppStrings.forgotPasswordBackToLogin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _onboardingPageController.dispose();
    _emailFocusNode.dispose();
    _emailController.dispose();
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
