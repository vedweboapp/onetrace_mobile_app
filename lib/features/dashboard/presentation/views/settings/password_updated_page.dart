import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_page.dart';

class PasswordUpdatedPage extends StatelessWidget {
  const PasswordUpdatedPage({super.key});

  static const path = '/settings/password-updated';
  static const name = 'settings-password-updated';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Material(
            color: AppColors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.go(SettingsPage.path),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.inkStrong,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.inkStrong.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFF111111),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Password Updated!',
                textAlign: TextAlign.center,
                style: AppFonts.headlineSmall(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 28),
              ),
              const SizedBox(height: 14),
              Text(
                'Your password has been changed\nsuccessfully. Use your new password\nto log in next time.',
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: const Color(0xFF6B7280))
                    .copyWith(fontSize: 16, height: 1.45),
              ),
              const SizedBox(height: 44),
              Icon(
                Icons.visibility_outlined,
                color: const Color(0xFFD1D5DB).withValues(alpha: 0.75),
                size: 32,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => context.go(SettingsPage.path),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Back to Settings',
                    style: AppFonts.titleMedium(color: AppColors.white)
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.showTopSnackBar(
                  const SnackBar(content: Text('Support is coming soon')),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: 'Need help?   ',
                      style: AppFonts.bodyMedium(
                        color: const Color(0xFF6B7280),
                      ).copyWith(fontWeight: FontWeight.w600),
                      children: [
                        TextSpan(
                          text: 'Contact Support  →',
                          style: AppFonts.bodyMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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
