import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/company_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/forms_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/integration_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/job_status_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_widgets.dart';
import 'package:red5/features/dashboard/presentation/views/settings/pin_status_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/project_type_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_feature_flags.dart';
import 'package:red5/features/dashboard/presentation/views/settings/tags_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/privacy_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';

class MetadataSettingsPage extends StatefulWidget {
  const MetadataSettingsPage({super.key});

  static const path = '/settings/metadata';
  static const name = 'settings-metadata';

  @override
  State<MetadataSettingsPage> createState() => _MetadataSettingsPageState();
}

class _MetadataSettingsPageState extends State<MetadataSettingsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _closeDrawerPush(String route) {
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push(route);
    });
  }

  void _logoutToDashboard() {
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(DashboardPage.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6F8),
      drawerEnableOpenDragGesture: true,
      drawer: _SettingsDrawer(
        selected: _SettingsDrawerSelection.metadata,
        onExit: _logoutToDashboard,
        onPersonalProfile: () => _closeDrawerPush(PersonalProfilePage.path),
        onUsers: () => _closeDrawerPush(UsersSettingsPage.path),
        onCompany: () => _closeDrawerPush(CompanySettingsPage.path),
        onPrivacy: () => _closeDrawerPush(PrivacySettingsPage.path),
        onMetadata: () => _scaffoldKey.currentState?.closeDrawer(),
        onIntegration: () => _closeDrawerPush(IntegrationSettingsPage.path),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: AppColors.inkStrong),
        ),
        title: Text(
          'Meta Data',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text(
              'SYSTEM METADATA',
              style: AppFonts.labelMedium(
                color: const Color(0xFF9CA3AF),
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),
            SystemMetadataCard(
              rows: [
                SystemMetadataRow(
                  icon: Icons.push_pin_rounded,
                  title: 'Pin Status',
                  moduleLabel: 'Project',
                  onTap: () => context.push(PinStatusSettingsPage.path),
                ),
                SystemMetadataRow(
                  icon: Icons.checklist_rounded,
                  title: 'Job Status',
                  moduleLabel: 'Job',
                  onTap: () => context.push(JobStatusSettingsPage.path),
                ),
                SystemMetadataRow(
                  icon: Icons.work_outline_rounded,
                  title: 'Project Type',
                  moduleLabel: 'Project',
                  onTap: () => context.push(ProjectTypeSettingsPage.path),
                ),
                SystemMetadataRow(
                  icon: Icons.work_outline_rounded,
                  title: 'Tags',
                  moduleLabel: 'Quotation',
                  onTap: () => context.push(TagsSettingsPage.path),
                ),
                SystemMetadataRow(
                  icon: Icons.description_outlined,
                  title: 'Forms',
                  moduleLabel: 'Job',
                  onTap: () => context.push(FormsSettingsPage.path),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _SettingsDrawerSelection {
  personalProfile,
  users,
  company,
  privacy,
  metadata,
  integration,
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
    required this.selected,
    required this.onExit,
    required this.onPersonalProfile,
    required this.onUsers,
    required this.onCompany,
    required this.onPrivacy,
    required this.onMetadata,
    required this.onIntegration,
  });

  final _SettingsDrawerSelection selected;
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
                    icon: const Icon(
                      Icons.exit_to_app_rounded,
                      color: AppColors.inkStrong,
                      size: 22,
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
                    selected:
                        selected == _SettingsDrawerSelection.personalProfile,
                    onTap: onPersonalProfile,
                  ),
                  _sidebarNavTile(
                    title: 'Users',
                    iconAsset: 'assets/images/public.png',
                    selected: selected == _SettingsDrawerSelection.users,
                    onTap: onUsers,
                  ),
                  _sidebarNavTile(
                    title: 'Company Settings',
                    iconAsset: 'assets/images/company.png',
                    selected: selected == _SettingsDrawerSelection.company,
                    onTap: onCompany,
                  ),
                  _sidebarNavTile(
                    title: 'Privacy',
                    iconAsset: 'assets/images/privacy.png',
                    selected: selected == _SettingsDrawerSelection.privacy,
                    onTap: onPrivacy,
                  ),
                  if (SettingsFeatureFlags.showMetaData) ...[
                    _sectionLabelCaps('CUSTOMISATION'),
                    _sidebarNavTile(
                      title: 'Meta Data',
                      iconAsset: 'assets/images/database (1).png',
                      selected: selected == _SettingsDrawerSelection.metadata,
                      enabled: SettingsFeatureFlags.metadataEnabled,
                      onTap: onMetadata,
                    ),
                  ],
                  _sectionLabelCaps('INTEGRATION'),
                  _sidebarNavTile(
                    title: 'Integration',
                    iconAsset: 'assets/images/integration.png',
                    selected: selected == _SettingsDrawerSelection.integration,
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
