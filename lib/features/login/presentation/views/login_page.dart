import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:red5/core/auth/auth_redirect_notifier.dart';
import 'package:red5/core/auth/auth_session.dart';
import 'package:red5/core/auth/user_role_navigation.dart';
import 'package:red5/core/di/injection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/storage/organization_id_storage.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/theme/app_screen_size.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/app_branded_logo_block.dart';
import 'package:red5/core/widgets/app_button.dart';
import 'package:red5/core/widgets/app_frosted_panel.dart';
import 'package:red5/core/widgets/app_screen_stack.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/features/login/presentation/views/forgot_password_page.dart';
import 'package:red5/features/login/presentation/views/otp_verify_page.dart';
import 'package:red5/features/login/presentation/widgets/signup_bottom_sheet.dart';
import 'package:red5/employee_role/data/role_session.dart';
import 'package:red5/employee_role/data/static_role_accounts.dart';

import '../../../../core/widgets/app_const_widget.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const path = '/login';
  static const name = 'login';
  static const signInButtonKey = ValueKey('login_sign_in_button');
  static const sendOtpButtonKey = ValueKey('login_send_otp_button');
  static const emailFieldKey = ValueKey('login_email_field');
  static const otpEmailFieldKey = ValueKey('login_otp_email_field');
  static const passwordFieldKey = ValueKey('login_password_field');

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _defaultLoginEmail = '';
  static const _defaultLoginPassword = '';

  static const _mobileDark = Color(0xFF111111);
  static const _mobileSubtextGray = Color(0xFF666666);
  static const _mobileBorder = Color(0xFFE0E0E0);
  static const _mobileDotInactive = Color(0xFF757575);

  final _formKey = GlobalKey<FormState>();
  final _mobilePasswordFormKey = GlobalKey<FormState>();
  final _mobileOtpFormKey = GlobalKey<FormState>();
  final _mobilePasswordScrollController = ScrollController();
  final _mobileOtpScrollController = ScrollController();
  late final PageController _mobileAuthPaneController;
  final _emailController = TextEditingController(text: _defaultLoginEmail);
  final _passwordController = TextEditingController(
    text: _defaultLoginPassword,
  );
  late final FocusNode _emailFocusNode;
  late final FocusNode _emailOtpFocusNode;
  late final FocusNode _passwordFocusNode;
  late final PageController _onboardingPageController;
  Timer? _onboardingAutoScrollTimer;
  int _onboardingPageIndex = 0;
  bool _rememberMe = false;
  bool _hidePassword = true;
  bool _isSigningIn = false;
  bool _isSendingOtp = false;

  static const _onboardingSlideCount = 3;

  void _scrollFocusedFieldIntoView(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.hasFocus) return;
      final ctx = node.context;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.12,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  EdgeInsets _loginFieldScrollPadding(BuildContext context) {
    final kb = AppScreenSize.keyboardInsetBottomOf(context);
    return EdgeInsets.fromLTRB(12, 72, 12, kb + 140);
  }

  @override
  void initState() {
    super.initState();
    _emailFocusNode = FocusNode();
    _emailOtpFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        _scrollFocusedFieldIntoView(_emailFocusNode);
      }
    });
    _emailOtpFocusNode.addListener(() {
      if (_emailOtpFocusNode.hasFocus) {
        _scrollFocusedFieldIntoView(_emailOtpFocusNode);
      }
    });
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        _scrollFocusedFieldIntoView(_passwordFocusNode);
      }
    });
    _onboardingPageController = PageController();
    _mobileAuthPaneController = PageController();
    _onboardingAutoScrollTimer = Timer.periodic(const Duration(seconds: 2), (
      _,
    ) {
      if (!mounted || !_onboardingPageController.hasClients) return;
      final next = (_onboardingPageIndex + 1) % _onboardingSlideCount;
      _onboardingPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storage = ref.read(localStorageProvider);
      if (storage.getBool(LocalStorageKeys.authRememberMe) == true) {
        final email = storage.getString(LocalStorageKeys.authSavedEmail);
        if (email != null && email.isNotEmpty) {
          setState(() {
            _emailController.text = email;
            _rememberMe = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _mobilePasswordScrollController.dispose();
    _mobileOtpScrollController.dispose();
    _mobileAuthPaneController.dispose();
    _emailFocusNode.dispose();
    _emailOtpFocusNode.dispose();
    _passwordFocusNode.dispose();
    _onboardingAutoScrollTimer?.cancel();
    _onboardingPageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  /// Uses image assets per slide:
  /// 0: site_work.png, 1: map_locator.png, 2: edit_pen.png
  Widget _onboardingMapIcon(int index) {
    const size = 52.0;
    final asset = switch (index) {
      0 => AppImageString.siteWorkPng,
      1 => AppImageString.mapSiteWorkPng,
      _ => AppImageString.editPenPng,
    };
    return Image.asset(
      asset,
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
            ).copyWith(height: 1.35, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _onSignIn() async {
    final narrow = context.isCompactLayout;
    final form = narrow
        ? _mobilePasswordFormKey.currentState
        : _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_isSigningIn) {
      return;
    }

    setState(() => _isSigningIn = true);
    try {
      final staticAccount = StaticRoleAccounts.authenticate(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (staticAccount != null) {
        final storage = ref.read(localStorageProvider);
        await storage.setString(
          LocalStorageKeys.authAccessToken,
          RoleSession.staticAccessToken(staticAccount.role),
        );
        await storage.remove(LocalStorageKeys.authRefreshToken);
        await storage.remove(LocalStorageKeys.authUserId);
        await RoleSession.persistRole(storage, staticAccount.role);
        if (_rememberMe) {
          await storage.setBool(LocalStorageKeys.authRememberMe, true);
          await storage.setString(
            LocalStorageKeys.authSavedEmail,
            _emailController.text.trim(),
          );
        } else {
          await storage.setBool(LocalStorageKeys.authRememberMe, false);
          await storage.remove(LocalStorageKeys.authSavedEmail);
        }
        if (!mounted) return;
        sl<AuthRedirectNotifier>().notifyAuthChanged();
        context.go(
          UserRoleNavigation.homePathForRoleName(staticAccount.role.label),
        );
        return;
      }

      final client = ref.read(authApiClientProvider);
      final response = await client.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final payload = AuthSession.coerceAuthPayload(response.data);
      if (payload == null) {
        if (!mounted) return;
        context.showTopSnackBar(
          const SnackBar(
            content: Text(
              'Sign-in succeeded but the session response was invalid.',
            ),
          ),
        );
        return;
      }

      final storage = ref.read(localStorageProvider);
      final accessToken = AuthSession.readAccessToken(payload);
      final refreshToken = AuthSession.readRefreshToken(payload);
      if (accessToken == null || !AuthSession.isJwtValid(accessToken)) {
        if (!mounted) return;
        context.showTopSnackBar(
          const SnackBar(
            content: Text(
              'Sign-in succeeded but no access token was returned. Please try again.',
            ),
          ),
        );
        return;
      }
      await storage.setString(LocalStorageKeys.authAccessToken, accessToken);
      if (refreshToken != null) {
        await storage.setString(
          LocalStorageKeys.authRefreshToken,
          refreshToken,
        );
      } else {
        await storage.remove(LocalStorageKeys.authRefreshToken);
      }
      final userId = AuthSession.readUserId(payload);
      if (userId != null && userId.isNotEmpty) {
        await storage.setString(LocalStorageKeys.authUserId, userId);
      } else {
        await storage.remove(LocalStorageKeys.authUserId);
      }
      await OrganizationIdStorage.persist(
        storage,
        AuthSession.readOrganizationId(payload),
      );
      final homePath = await UserRoleNavigation.resolveAndPersistHomePath(
        storage: storage,
        profileClient: sl<UserProfileApiClient>(),
      );
      if (_rememberMe) {
        await storage.setBool(LocalStorageKeys.authRememberMe, true);
        await storage.setString(
          LocalStorageKeys.authSavedEmail,
          _emailController.text.trim(),
        );
      } else {
        await storage.setBool(LocalStorageKeys.authRememberMe, false);
        await storage.remove(LocalStorageKeys.authSavedEmail);
      }

      if (!mounted) return;
      sl<AuthRedirectNotifier>().notifyAuthChanged();
      context.go(homePath);
    } on DioException catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromDioException(
              e,
              genericFallback: AppStrings.apiErrorSignInFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _onSendOtp() async {
    if (!(_mobileOtpFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_isSendingOtp) return;
    final email = _emailController.text.trim();
    setState(() => _isSendingOtp = true);
    try {
      final client = ref.read(authApiClientProvider);
      await client.sendOtp(
        email: email,
        extraFields: const {'purpose': 'login'},
      );
      if (!mounted) return;
      context.push(
        Uri(
          path: OtpVerifyPage.path,
          queryParameters: {'email': email},
        ).toString(),
      );
    } on DioException catch (e) {
      if (!mounted) return;
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
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  void _goToMobileOtpPane() {
    FocusScope.of(context).unfocus();
    unawaited(
      _mobileAuthPaneController.animateToPage(
        1,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _goToMobilePasswordPane() {
    FocusScope.of(context).unfocus();
    unawaited(
      _mobileAuthPaneController.animateToPage(
        0,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  EdgeInsets _mobileFormPadding(double bottomInset, double keyboardInset) {
    return EdgeInsets.fromLTRB(22, 28, 22, 24 + bottomInset + keyboardInset);
  }

  /// Outlined secondary action — same style on password and OTP panes.
  Widget _mobileOutlinedAuthActionButton(
    BuildContext context, {
    Key? key,
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
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
        child: child,
      ),
    );
  }

  Widget _buildMobilePasswordAuthPane(
    BuildContext context, {
    required double bottomInset,
    required double keyboardInset,
  }) {
    return SingleChildScrollView(
      controller: _mobilePasswordScrollController,
      primary: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: _mobileFormPadding(bottomInset, keyboardInset),
      child: Form(
        key: _mobilePasswordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.loginWelcomeBack,
              style: AppFonts.headlineSmall(color: _mobileDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 26,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.loginWelcomeSubtitle,
              style: AppFonts.bodyMedium(
                color: _mobileSubtextGray,
              ).copyWith(fontSize: 14),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _emailFocusNode.requestFocus(),
              child: Text(
                AppStrings.emailLabel,
                style: AppFonts.labelLarge(
                  color: _mobileDark,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              key: LoginPage.emailFieldKey,
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_passwordFocusNode),
              hintText: AppStrings.loginEmailHintRegistered,
              scrollPadding: _loginFieldScrollPadding(context),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _passwordFocusNode.requestFocus(),
              child: Text(
                AppStrings.passwordLabel,
                style: AppFonts.labelLarge(
                  color: _mobileDark,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              key: LoginPage.passwordFieldKey,
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              hintText: AppStrings.loginPasswordHintShort,
              scrollPadding: _loginFieldScrollPadding(context),
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
              validator: (value) {
                if ((value ?? '').length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            vGap(8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(ForgotPasswordPage.path),
                style: TextButton.styleFrom(
                  foregroundColor: _mobileDark,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppFonts.labelLarge(
                    color: _mobileDark,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                child: const Text(AppStrings.forgotPassword),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: LoginPage.signInButtonKey,
                onPressed: _isSigningIn ? null : _onSignIn,
                style: FilledButton.styleFrom(
                  backgroundColor: _mobileDark,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: _mobileDark.withValues(alpha: 0.45),
                  disabledForegroundColor: AppColors.white.withValues(
                    alpha: 0.7,
                  ),
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
                  _isSigningIn ? 'Signing in…' : AppStrings.loginSignInLower,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _mobileOutlinedAuthActionButton(
              context,
              onPressed: _goToMobileOtpPane,
              child: const Text(AppStrings.loginSignInWithOtp),
            ),
            const SizedBox(height: 28),
            _buildMobileLoginFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileOtpAuthPane(
    BuildContext context, {
    required double bottomInset,
    required double keyboardInset,
  }) {
    return SingleChildScrollView(
      controller: _mobileOtpScrollController,
      primary: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: _mobileFormPadding(bottomInset, keyboardInset),
      child: Form(
        key: _mobileOtpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.loginOtpHeadline,
              style: AppFonts.headlineSmall(color: _mobileDark).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 26,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.loginOtpSubtitle,
              style: AppFonts.bodyMedium(
                color: _mobileSubtextGray,
              ).copyWith(fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _emailOtpFocusNode.requestFocus(),
              child: Text(
                AppStrings.emailLabel,
                style: AppFonts.labelLarge(
                  color: _mobileDark,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              key: LoginPage.otpEmailFieldKey,
              controller: _emailController,
              focusNode: _emailOtpFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_onSendOtp()),
              hintText: AppStrings.loginEmailHintRegistered,
              scrollPadding: _loginFieldScrollPadding(context),
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
                key: LoginPage.sendOtpButtonKey,
                onPressed: _isSendingOtp ? null : () => unawaited(_onSendOtp()),
                style: FilledButton.styleFrom(
                  backgroundColor: _mobileDark,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: _mobileDark.withValues(alpha: 0.45),
                  disabledForegroundColor: AppColors.white.withValues(
                    alpha: 0.7,
                  ),
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
                  _isSendingOtp ? 'Sending…' : AppStrings.loginSendOtpCode,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _mobileOutlinedAuthActionButton(
              context,
              onPressed: _goToMobilePasswordPane,
              child: const Text(AppStrings.loginBackToPasswordSignIn),
            ),
            const SizedBox(height: 24),
            _buildMobileLoginFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLoginFooter(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        spacing: 0,
        children: [
          Text(
            '${AppStrings.loginNoAccountQuestion} ',
            style: AppFonts.bodyMedium(
              color: _mobileSubtextGray,
            ).copyWith(fontSize: 14),
          ),
          GestureDetector(
            onTap: () => showSignupBottomSheet(context),
            child: Text(
              AppStrings.loginSignUpLink,
              style: AppFonts.bodyMedium(
                color: _mobileDark,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final bottomInset = context.appScreenPadding.bottom;
    final keyboardInset = context.appKeyboardInsetBottom;
    const headerFlex = 36;
    const formFlex = 64;

    return Scaffold(
      backgroundColor: _mobileDark,
      // Keep the hero header + sheet split stable; only the inner form scrolls
      // so the focused field moves slightly above the keyboard instead of
      // resizing the whole screen.
      resizeToAvoidBottomInset: false,
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: ColoredBox(
                color: AppColors.white,
                child: SafeArea(
                  top: false,
                  child: PageView(
                    controller: _mobileAuthPaneController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildMobilePasswordAuthPane(
                        context,
                        bottomInset: bottomInset,
                        keyboardInset: keyboardInset,
                      ),
                      _buildMobileOtpAuthPane(
                        context,
                        bottomInset: bottomInset,
                        keyboardInset: keyboardInset,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: AppScreenStack(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    AppBrandedLogoBlock(
                      tagline: AppStrings.splashTagline.toUpperCase(),
                    ),
                    const SizedBox(height: 24),
                    AppFrostedPanel(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppStrings.loginTitle,
                              style: AppFonts.headlineSmall().copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              AppStrings.emailLabel,
                              style: AppFonts.labelLarge(
                                color: AppColors.ink,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              hintText: 'Enter your email',
                              prefixIcon: Icons.mail_outline,
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty || !email.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            Text(
                              AppStrings.passwordLabel,
                              style: AppFonts.labelLarge(
                                color: AppColors.ink,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            AppTextField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              hintText: 'Enter your password',
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _hidePassword = !_hidePassword;
                                  });
                                },
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textFieldHint,
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            AppButton(
                              key: LoginPage.signInButtonKey,
                              label: _isSigningIn ? 'Signing in…' : 'Sign In',
                              icon: Icons.arrow_forward,
                              onPressed: _isSigningIn ? null : _onSignIn,
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isCompactLayout) {
      return _buildMobileLayout(context);
    }
    return _buildWideLayout(context);
  }
}
