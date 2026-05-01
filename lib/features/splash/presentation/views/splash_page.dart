import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/widgets/app_branded_logo_block.dart';
import 'package:red5/core/widgets/app_frosted_panel.dart';
import 'package:red5/core/widgets/app_screen_stack.dart';
import 'package:red5/features/login/presentation/views/login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static const path = '/';
  static const name = 'splash';

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _loaderController;
  late final AnimationController _pulseController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        context.go(LoginPage.path);
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _loaderController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: AppScreenStack(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppFrostedPanel(
                  padding: const EdgeInsets.all(28),
                  fillAlpha: 0.82,
                  child: AppBrandedLogoBlock(
                    tagline: AppStrings.splashTagline.toUpperCase(),
                    titleStyle: theme.textTheme.displayLarge?.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                    ),
                    taglineStyle: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.brown,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _loaderController,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: _loaderController.value,
                            backgroundColor: AppColors.muted.withValues(alpha: 0.2),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.brandPrimary.withValues(
                                  alpha: 0.35 + (_pulseController.value * 0.55),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.splashLoadingText.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.75),
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
