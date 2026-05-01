import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/widgets/app_auth_text_field.dart';
import 'package:red5/core/widgets/app_branded_logo_block.dart';
import 'package:red5/core/widgets/app_button.dart';
import 'package:red5/core/widgets/app_frosted_panel.dart';
import 'package:red5/core/widgets/app_screen_stack.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const path = '/login';
  static const name = 'login';
  static const signInButtonKey = ValueKey('login_sign_in_button');

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final storage = ref.read(localStorageProvider);
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
    context.go(DashboardPage.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                AppStrings.emailLabel,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AppAuthTextField(
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
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AppAuthTextField(
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
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                  ),
                                  Text(
                                    AppStrings.rememberMe,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: TextButton(
                                      onPressed: () {},
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.brandPrimary,
                                        textStyle: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.brandPrimary,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        AppStrings.forgotPassword,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AppButton(
                                key: LoginPage.signInButtonKey,
                                label: 'Sign In',
                                icon: Icons.arrow_forward,
                                onPressed: _onSignIn,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      AppStrings.noAccount,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Flexible(
                                    child: TextButton(
                                      onPressed: () {},
                                      child: const Text(
                                        AppStrings.requestAccess,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
}
