import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/auth/auth_redirect_notifier.dart';
import 'package:red5/core/auth/auth_session.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/login/presentation/views/login_page.dart';
import 'package:red5/employee_role/data/role_session.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static const path = '/';
  static const name = 'splash';

  static const _simhoLogoAsset = 'assets/images/Simho logo.jpg';

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
      unawaited(_routeAfterSessionCheck());
    });
  }

  Future<void> _routeAfterSessionCheck() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final storage = container.read(localStorageProvider);
    final authApi = container.read(authApiClientProvider);

    final access = storage.getString(LocalStorageKeys.authAccessToken)?.trim();
    if (AuthSession.isJwtValid(access)) {
      if (!mounted) return;
      sl<AuthRedirectNotifier>().notifyAuthChanged();
      context.go(
        RoleSession.homePathForStoredRole(storage) ?? DashboardPage.homePath,
      );
      return;
    }

    final refresh = storage
        .getString(LocalStorageKeys.authRefreshToken)
        ?.trim();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        final refreshResponse = await authApi.refreshToken(
          refreshToken: refresh,
        );
        final refreshPayload = AuthSession.coerceAuthPayload(
          refreshResponse.data,
        );
        final newAccess = AuthSession.readAccessToken(refreshPayload);
        final newRefresh = AuthSession.readRefreshToken(refreshPayload);
        if (newAccess != null && newAccess.isNotEmpty) {
          await storage.setString(LocalStorageKeys.authAccessToken, newAccess);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            await storage.setString(
              LocalStorageKeys.authRefreshToken,
              newRefresh,
            );
          }
          if (!mounted) return;
          sl<AuthRedirectNotifier>().notifyAuthChanged();
          context.go(
            RoleSession.homePathForStoredRole(storage) ??
                DashboardPage.homePath,
          );
          return;
        }
      } catch (_) {
        // Fall through to login when refresh fails.
      }
    }

    await storage.remove(LocalStorageKeys.authAccessToken);
    await storage.remove(LocalStorageKeys.authRefreshToken);
    await storage.remove(LocalStorageKeys.authUserId);
    await RoleSession.clearRole(storage);
    if (!mounted) return;
    sl<AuthRedirectNotifier>().notifyAuthChanged();
    context.go(LoginPage.path);
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
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 200),
                child: Image.asset(
                  SplashPage._simhoLogoAsset,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.apartment_rounded,
                          size: 72,
                          color: AppColors.muted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.appName,
                          style: AppFonts.headlineSmall(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                AppStrings.splashTagline,
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(
                  color: AppColors.muted,
                ).copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _loaderController,
                    builder: (context, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: _loaderController.value,
                          backgroundColor: AppColors.borderLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.inkStrong,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.inkStrong.withValues(
                                alpha: 0.25 + (_pulseController.value * 0.45),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppStrings.splashLoadingText.toUpperCase(),
                        style: AppFonts.labelSmall(
                          color: AppColors.muted,
                        ).copyWith(
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
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
    );
  }
}
