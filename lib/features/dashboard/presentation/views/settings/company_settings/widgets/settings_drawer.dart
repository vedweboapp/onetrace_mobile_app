part of '../company_settings.dart';

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

