import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  static const path = '/settings/company';
  static const name = 'settings-company';

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

enum _AppearanceMode { light, dark }

enum _NavigationStyle { sidebar, bottomBar }

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _companyNameController =
      TextEditingController(text: 'Apex Construction Solutions');

  _AppearanceMode _appearanceMode = _AppearanceMode.light;
  _NavigationStyle _navigationStyle = _NavigationStyle.sidebar;
  int _selectedBrandColor = 0;
  Color? _customBrandColor;

  static const _pageBackground = Color(0xFFF3F4F6);
  static const _panelBorder = Color(0xFFE5E7EB);
  static const _labelGrey = Color(0xFF6B7280);
  static const _photoCaption = Color(0xFF6B8FA8);

  static const _brandPalette = <Color>[
    Color(0xFF000000), // #000000
    Color(0xFFF97316), // #F97316
    Color(0xFF2563EB), // #2563EB
    Color(0xFF059669), // #059669
    Color(0xFF4B5563), // #4B5563
  ];
  static const _customSheetPalette = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFF59E0B),
    Color(0xFFEA580C),
    Color(0xFFE11D48),
    Color(0xFF1E293B),
    Color(0xFF38BDF8),
    Color(0xFF84CC16),
  ];

  @override
  void dispose() {
    _companyNameController.dispose();
    super.dispose();
  }

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

  Widget _sectionHeader(String uppercaseTitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.inkStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            uppercaseTitle,
            style: AppFonts.labelMedium(color: _labelGrey).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _profilePhotoPicker() {
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DottedBorder(
                  options: RoundedRectDottedBorderOptions(
                    radius: const Radius.circular(66),
                    strokeWidth: 1.8,
                    color: const Color(0xFFD1D5DB),
                    dashPattern: const [5, 4],
                  ),
                  child: Container(
                    width: 124,
                    height: 124,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF5F6F8),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 46,
                      color: AppColors.mutedLight,
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 8,
                  child: Material(
                    color: const Color(0xFF111827),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload Profile Photo (Optional)',
            style: AppFonts.bodyMedium(color: _photoCaption).copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appearanceToggle() {
    final selectedBg = AppColors.white;
    final baseBg = const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AppearanceButton(
              icon: Icons.wb_sunny_rounded,
              label: 'Light',
              selected: _appearanceMode == _AppearanceMode.light,
              selectedColor: _brandPalette[1],
              selectedBg: selectedBg,
              onTap: () => setState(() => _appearanceMode = _AppearanceMode.light),
            ),
          ),
          Expanded(
            child: _AppearanceButton(
              icon: Icons.nightlight_round,
              label: 'Dark',
              selected: _appearanceMode == _AppearanceMode.dark,
              selectedColor: _brandPalette[4],
              selectedBg: selectedBg,
              onTap: () => setState(() => _appearanceMode = _AppearanceMode.dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandColorRow() {
    return Row(
      children: [
        for (var i = 0; i < _brandPalette.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i == _brandPalette.length - 1 ? 0 : 10),
            child: InkWell(
              onTap: () => setState(() => _selectedBrandColor = i),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _brandPalette[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedBrandColor == i
                        ? Colors.black
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: _selectedBrandColor == i
                    ? Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: i == 0 ? Colors.white : Colors.black,
                      )
                    : null,
              ),
            ),
          ),
        if (_customBrandColor != null) ...[
          const SizedBox(width: 10),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _customBrandColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
        const SizedBox(width: 8),
        InkWell(
          onTap: _showBrandColorBottomSheet,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(Icons.add, color: Color(0xFF9CA3AF), size: 18),
          ),
        ),
      ],
    );
  }

  String _hexOf(Color color) {
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${hex.substring(2)}';
  }

  void _showBrandColorBottomSheet() {
    final initialColor = _brandPalette[_selectedBrandColor];
    final initialIndex = _customSheetPalette.indexWhere(
      (c) => c.value == initialColor.value,
    );
    var localIndex = initialIndex < 0 ? 0 : initialIndex;
    var selectedColor = _customSheetPalette[localIndex];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Brand Color',
                          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: selectedColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _hexOf(selectedColor),
                            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'CUSTOM',
                            style: AppFonts.labelSmall(color: const Color(0xFF2563EB)).copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < _customSheetPalette.length; i++)
                          InkWell(
                            onTap: () {
                              setBottomState(() {
                                localIndex = i;
                                selectedColor = _customSheetPalette[i];
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _customSheetPalette[i],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: i == localIndex
                                      ? const Color(0xFF93C5FD)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: i == localIndex
                                  ? const Icon(Icons.check_rounded, color: Colors.white)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          final color = _customSheetPalette[localIndex];
                          setState(() {
                            final existingIndex = _brandPalette.indexWhere(
                              (c) => c.value == color.value,
                            );
                            if (existingIndex >= 0) {
                              _selectedBrandColor = existingIndex;
                              _customBrandColor = null;
                            } else {
                              _customBrandColor = color;
                            }
                          });
                          Navigator.of(ctx).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Apply Color',
                          style: AppFonts.labelLarge(color: Colors.white).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _pageBackground,
      drawerEnableOpenDragGesture: true,
      drawer: _SettingsDrawer(
        selected: _SettingsDrawerSelection.company,
        onExit: _logoutToDashboard,
        onPersonalProfile: () => _closeDrawerPush(PersonalProfilePage.path),
        onUsers: () => _closeDrawerPush(UsersSettingsPage.path),
        onCompany: () => _scaffoldKey.currentState?.closeDrawer(),
        onMetadata: () => _closeDrawerPush(MetadataSettingsPage.path),
      ),
      appBar: AppBar(
        backgroundColor: _pageBackground,
        surfaceTintColor: _pageBackground,
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: AppColors.inkStrong),
        ),
        title: Text(
          'Company Settings',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  Text(
                    'COMPANY PROFILE',
                    style: AppFonts.labelMedium(color: _labelGrey).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _profilePhotoPicker(),
                  const SizedBox(height: 20),
                  _smallHeading('Company Name'),
                  AppTextField(
                    controller: _companyNameController,
                    hintText: '',
                    textStyle: AppFonts.bodyLarge(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w500),
                    hintStyle: const TextStyle(color: Colors.transparent, height: 0),
                  ),
                  const SizedBox(height: 22),
                  const Divider(color: _panelBorder, height: 1),
                  const SizedBox(height: 14),
                  _sectionHeader('VISUAL THEME'),
                  _smallHeading('Appearance'),
                  _appearanceToggle(),
                  const SizedBox(height: 18),
                  _smallHeading('Brand Color'),
                  _brandColorRow(),
                  const SizedBox(height: 22),
                  const Divider(color: _panelBorder, height: 1),
                  const SizedBox(height: 14),
                  _sectionHeader('PLATFORM LAYOUT'),
                  _smallHeading('Navigation Style'),
                  _NavigationTile(
                    selected: _navigationStyle == _NavigationStyle.sidebar,
                    title: 'Sidebar Navigation',
                    subtitle: 'Traditional vertical menu',
                    icon: Icons.apps_rounded,
                    onTap: () => setState(
                      () => _navigationStyle = _NavigationStyle.sidebar,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _NavigationTile(
                    selected: _navigationStyle == _NavigationStyle.bottomBar,
                    title: 'Bottom Bar Menu',
                    subtitle: 'Compact tab style for mobile',
                    icon: Icons.space_dashboard_rounded,
                    onTap: () => setState(
                      () => _navigationStyle = _NavigationStyle.bottomBar,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _panelBorder)),
              ),
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                MediaQuery.of(context).padding.bottom + 10,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandPalette[0],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: AppFonts.labelLarge(color: Colors.white).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceButton extends StatelessWidget {
  const _AppearanceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedBg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedBg : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? selectedColor : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppFonts.bodyMedium(
                  color: selected ? AppColors.inkStrong : const Color(0xFF6B7280),
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.black : const Color(0xFFE5E7EB),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF6B7280), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF6B7280),
                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.black : Colors.transparent,
                  border: Border.all(
                    color: selected ? Colors.black : const Color(0xFFD1D5DB),
                    width: 1.8,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.circle, size: 6, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SettingsDrawerSelection { personalProfile, users, company, metadata }

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
    required this.selected,
    required this.onExit,
    required this.onPersonalProfile,
    required this.onUsers,
    required this.onCompany,
    required this.onMetadata,
  });

  final _SettingsDrawerSelection selected;
  final VoidCallback onExit;
  final VoidCallback onPersonalProfile;
  final VoidCallback onUsers;
  final VoidCallback onCompany;
  final VoidCallback onMetadata;

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
                    selected: selected == _SettingsDrawerSelection.personalProfile,
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
                  _sectionLabelCaps('CUSTOMISATION'),
                  _sidebarNavTile(
                    title: 'Meta Data',
                    iconAsset: 'assets/images/database (1).png',
                    selected: selected == _SettingsDrawerSelection.metadata,
                    onTap: onMetadata,
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
                    style: AppFonts.bodyMedium(
                      color: selected
                          ? AppColors.inkStrong
                          : const Color(0xFF525860),
                    ).copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
