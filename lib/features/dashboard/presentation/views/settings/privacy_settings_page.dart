import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/employee_home/employee_home_page.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/technician_settings_drawer.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/change_password_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/company_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/integration_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_feature_flags.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';

/// Privacy settings: change password entry + active sessions overview.
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({
    super.key,
    this.useTechnicianSettingsNav = false,
  });

  /// When true (technician routes), drawer shows only Profile + Privacy and exit returns to [TechnicianHomePage].
  final bool useTechnicianSettingsNav;

  static const path = '/settings/privacy';
  static const name = 'settings-privacy';

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _closeDrawerPush(String route) {
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push(route);
    });
  }

  void _closeDrawerPopToProfile() {
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.pushReplacement(EmployeeTechnicianSettingsRoutes.personalProfile);
      }
    });
  }

  void _logoutToDashboard() {
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.useTechnicianSettingsNav) {
        context.go(TechnicianHomePage.path);
      } else {
        context.go(DashboardPage.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      drawerEnableOpenDragGesture: true,
      drawer: widget.useTechnicianSettingsNav
          ? TechnicianSettingsDrawer(
              selected: TechnicianSettingsSection.privacy,
              onExit: _logoutToDashboard,
              onPersonalProfile: _closeDrawerPopToProfile,
              onPrivacy: () => _scaffoldKey.currentState?.closeDrawer(),
            )
          : _PrivacyDrawer(
              onExit: _logoutToDashboard,
              onPersonalProfile: () =>
                  _closeDrawerPush(PersonalProfilePage.path),
              onUsers: () => _closeDrawerPush(UsersSettingsPage.path),
              onCompany: () => _closeDrawerPush(CompanySettingsPage.path),
              onPrivacy: () => _scaffoldKey.currentState?.closeDrawer(),
              onMetadata: () => _closeDrawerPush(MetadataSettingsPage.path),
              onIntegration: () =>
                  _closeDrawerPush(IntegrationSettingsPage.path),
            ),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.inkStrong),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Privacy',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            _sectionLabel('MODULE NAME'),
            const SizedBox(height: 10),
            _ChangePasswordTile(
              onTap: () => context.push(ChangePasswordPage.path),
            ),
            const SizedBox(height: 22),
            _sectionLabel('ACTIVE SESSIONS'),
            const SizedBox(height: 10),
            const _ActiveSessionTile(
              deviceName: 'iPhone 15 Pro',
              description: 'Current Session • London, UK',
              isActive: true,
            ),
            const SizedBox(height: 36),
            Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  "assets/images/disclaimer.png",
                  height: 16,
                  width: 16,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Your account security is our priority. RED 5 uses industry standard encryption to protect your data.',
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(
                  color: const Color(0xFF6B7280),
                ).copyWith(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppFonts.labelMedium(
        color: const Color(0xFF9CA3AF),
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.9, fontSize: 11),
    );
  }
}

class _ChangePasswordTile extends StatelessWidget {
  const _ChangePasswordTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: AppColors.shadowCard,
      color: AppColors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    "assets/images/change_password.png",
                    height: 15,
                    width: 15,
                    color: AppColors.inkStrong,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Change Password',
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveSessionTile extends StatelessWidget {
  const _ActiveSessionTile({
    required this.deviceName,
    required this.description,
    required this.isActive,
  });

  final String deviceName;
  final String description;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.smartphone_rounded,
              size: 18,
              color: AppColors.inkStrong,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppFonts.bodyMedium(
                    color: const Color(0xFF6B7280),
                  ).copyWith(fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEEF0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'INACTIVE',
              style: AppFonts.labelMedium(color: const Color(0xFF374151))
                  .copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyDrawer extends StatelessWidget {
  const _PrivacyDrawer({
    required this.onExit,
    required this.onPersonalProfile,
    required this.onUsers,
    required this.onCompany,
    required this.onPrivacy,
    required this.onMetadata,
    required this.onIntegration,
  });

  final VoidCallback onExit;
  final VoidCallback onPersonalProfile;
  final VoidCallback onUsers;
  final VoidCallback onCompany;
  final VoidCallback onPrivacy;
  final VoidCallback onMetadata;
  final VoidCallback onIntegration;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      width: MediaQuery.sizeOf(context).width * 0.82,
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    'RED 5',
                    style: AppFonts.headlineSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Exit',
                    onPressed: onExit,
                    icon: Image.asset(
                      "assets/images/Vector.png",
                      color: AppColors.inkStrong,
                      height: 15,
                      width: 15,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  _sectionLabelCaps('GENERAL'),
                  _sidebarNavTile(
                    title: 'Personal Profile',
                    iconAsset: 'assets/images/person.png',
                    selected: false,
                    onTap: onPersonalProfile,
                  ),
                  _sidebarNavTile(
                    title: 'Users',
                    iconAsset: 'assets/images/public.png',
                    selected: false,
                    onTap: onUsers,
                  ),
                  _sidebarNavTile(
                    title: 'Company Settings',
                    iconAsset: 'assets/images/company.png',
                    selected: false,
                    onTap: onCompany,
                  ),
                  _sidebarNavTile(
                    title: 'Privacy',
                    iconAsset: 'assets/images/privacy.png',
                    selected: true,
                    onTap: onPrivacy,
                  ),
                  if (SettingsFeatureFlags.showMetaData) ...[
                    _sectionLabelCaps('CUSTOMISATION'),
                    _sidebarNavTile(
                      title: 'Meta Data',
                      iconAsset: 'assets/images/database (1).png',
                      selected: false,
                      enabled: SettingsFeatureFlags.metadataEnabled,
                      onTap: onMetadata,
                    ),
                  ],
                  _sectionLabelCaps('INTEGRATION'),
                  _sidebarNavTile(
                    title: 'Integration',
                    iconAsset: 'assets/images/integration.png',
                    selected: false,
                    onTap: onIntegration,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabelCaps(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text,
        style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF)).copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _sidebarNavTile({
    required String title,
    required String iconAsset,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final inactiveColor =
        enabled ? const Color(0xFF525860) : const Color(0xFF9CA3AF);
    final iconColor = enabled ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected && enabled
            ? const Color(0xFFF2F2F4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Image.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                  color: iconColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style:
                        AppFonts.bodyMedium(
                          color: selected && enabled
                              ? AppColors.inkStrong
                              : inactiveColor,
                        ).copyWith(
                          fontWeight: selected && enabled
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 15,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
