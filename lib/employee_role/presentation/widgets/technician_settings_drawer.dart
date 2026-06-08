import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

enum TechnicianSettingsSection { personalProfile, privacy }

/// Same visual language as admin settings drawer; only Profile + Privacy.
class TechnicianSettingsDrawer extends StatelessWidget {
  const TechnicianSettingsDrawer({
    super.key,
    required this.selected,
    required this.onExit,
    required this.onPersonalProfile,
    required this.onPrivacy,
  });

  final TechnicianSettingsSection selected;
  final VoidCallback onExit;
  final VoidCallback onPersonalProfile;
  final VoidCallback onPrivacy;

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
                      'assets/images/Vector.png',
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
                    selected:
                        selected == TechnicianSettingsSection.personalProfile,
                    onTap: onPersonalProfile,
                  ),
                  _sidebarNavTile(
                    title: 'Privacy',
                    iconAsset: 'assets/images/privacy.png',
                    selected: selected == TechnicianSettingsSection.privacy,
                    onTap: onPrivacy,
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? const Color(0xFFF2F2F4) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Image.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                  color: const Color(0xFF4B5563),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style:
                        AppFonts.bodyMedium(
                          color: selected
                              ? AppColors.inkStrong
                              : const Color(0xFF525860),
                        ).copyWith(
                          fontWeight: selected
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
