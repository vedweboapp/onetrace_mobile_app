import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/company_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/integration_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_feature_flags.dart';
import 'package:red5/features/dashboard/presentation/views/settings/privacy_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';

/// Full-screen settings hub. Sub-pages are pushed on top so [context.pop]
/// returns here instead of closing a dialog.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const path = '/settings';
  static const name = 'settings';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDEE),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Settings',
                        textAlign: TextAlign.center,
                        style: AppFonts.titleMedium(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFD8D8DA)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(DashboardPage.path),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Close',
                        style: AppFonts.bodyMedium(
                          color: Colors.white,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'GENERAL',
                  style: AppFonts.labelMedium(color: const Color(0xFF5F6672))
                      .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        fontSize: 16,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              const _SettingsMenuRow(
                iconAsset: 'assets/images/person.png',
                title: 'Personal Profile',
                route: PersonalProfilePage.path,
              ),
              const _SettingsMenuRow(
                iconAsset: 'assets/images/public.png',
                title: 'Users',
                route: UsersSettingsPage.path,
              ),
              const _SettingsMenuRow(
                iconAsset: 'assets/images/company.png',
                title: 'Company Settings',
                route: CompanySettingsPage.path,
              ),
              const _SettingsMenuRow(
                iconAsset: 'assets/images/privacy.png',
                title: 'Privacy',
                route: PrivacySettingsPage.path,
              ),
              if (SettingsFeatureFlags.showMetaData) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'CUSTOMISATION',
                    style: AppFonts.labelMedium(color: const Color(0xFF5F6672))
                        .copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          fontSize: 16,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsMenuRow(
                  iconAsset: 'assets/images/database (1).png',
                  title: 'Meta Data',
                  route: MetadataSettingsPage.path,
                  enabled: SettingsFeatureFlags.metadataEnabled,
                ),
                const SizedBox(height: 20),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'INTEGRATION',
                  style: AppFonts.labelMedium(color: const Color(0xFF5F6672))
                      .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        fontSize: 16,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              const _SettingsMenuRow(
                iconAsset: 'assets/images/integration.png',
                title: 'Integration',
                route: IntegrationSettingsPage.path,
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({
    required this.iconAsset,
    required this.title,
    required this.route,
    this.enabled = true,
  });

  final String iconAsset;
  final String title;
  final String route;
  final bool enabled;

  static const _disabledFg = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? AppColors.inkStrong : _disabledFg;
    final iconColor = enabled
        ? const Color.fromARGB(255, 18, 18, 18)
        : _disabledFg;

    return InkWell(
      onTap: enabled ? () => context.push(route) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFD8D8DA))),
        ),
        child: Row(
          children: [
            Image.asset(
              iconAsset,
              color: iconColor,
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppFonts.titleMedium(
                  color: fg,
                ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: enabled ? const Color(0xFF4B5563) : _disabledFg,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
