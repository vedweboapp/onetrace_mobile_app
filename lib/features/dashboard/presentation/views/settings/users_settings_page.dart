import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/company_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/invite_user_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';

/// User directory: search, status filters, list, FAB — matches RED5 settings visual language.
class UsersSettingsPage extends StatefulWidget {
  const UsersSettingsPage({super.key});

  static const path = '/settings/users';
  static const name = 'settings-users';

  @override
  State<UsersSettingsPage> createState() => _UsersSettingsPageState();
}

enum _UserDirectoryStatus { active, inactive, invited }

enum _UserFilterTab { active, inactive, invited }

class _UserRowData {
  const _UserRowData({
    required this.name,
    required this.role,
    required this.createdByLabel,
    required this.directoryStatus,
    this.useInitialsAvatar = false,
  });

  final String name;
  final String role;
  final String createdByLabel;
  final _UserDirectoryStatus directoryStatus;

  /// When true, show colored circle with initials; when false, gray person icon.
  final bool useInitialsAvatar;
}

class _UsersSettingsPageState extends State<UsersSettingsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  _UserFilterTab _filterTab = _UserFilterTab.active;

  static final List<_UserRowData> _allUsers = [
    const _UserRowData(
      name: 'Sarah Miller',
      role: 'Lead Architect',
      createdByLabel: 'Created By : Admin',
      directoryStatus: _UserDirectoryStatus.inactive,
    ),
    const _UserRowData(
      name: 'James Lee',
      role: 'Senior Developer',
      createdByLabel: 'Created By : Admin',
      directoryStatus: _UserDirectoryStatus.active,
      useInitialsAvatar: true,
    ),
    const _UserRowData(
      name: 'Emily Johns',
      role: 'Product Manager',
      createdByLabel: 'Created By : Admin',
      directoryStatus: _UserDirectoryStatus.invited,
      useInitialsAvatar: true,
    ),
    const _UserRowData(
      name: 'Michael Smith',
      role: 'UI/UX Designer',
      createdByLabel: 'Created By : Admin',
      directoryStatus: _UserDirectoryStatus.inactive,
    ),
    const _UserRowData(
      name: 'Anna Brown',
      role: 'QA Tester',
      createdByLabel: 'Created By : Admin',
      directoryStatus: _UserDirectoryStatus.active,
      useInitialsAvatar: true,
    ),
    const _UserRowData(
      name: 'David Wilson',
      role: 'Data Analyst',
      createdByLabel: 'Created By : Admin',
      directoryStatus: _UserDirectoryStatus.inactive,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
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

  _UserDirectoryStatus? get _filterStatusMatch {
    switch (_filterTab) {
      case _UserFilterTab.active:
        return _UserDirectoryStatus.active;
      case _UserFilterTab.inactive:
        return _UserDirectoryStatus.inactive;
      case _UserFilterTab.invited:
        return _UserDirectoryStatus.invited;
    }
  }

  List<_UserRowData> get _visibleUsers {
    final q = _searchController.text.trim().toLowerCase();
    final status = _filterStatusMatch;
    return _allUsers.where((u) {
      if (u.directoryStatus != status) return false;
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      drawerEnableOpenDragGesture: true,
      drawer: _SettingsDrawer(
        selection: _SettingsDrawerSelection.users,
        onExit: _logoutToDashboard,
        onPersonalProfile: () => _closeDrawerPush(PersonalProfilePage.path),
        onUsers: () => _scaffoldKey.currentState?.closeDrawer(),
        onCompany: () => _closeDrawerPush(CompanySettingsPage.path),
        onMetadata: () => _closeDrawerPush(MetadataSettingsPage.path),
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
          'User',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        onPressed: () => context.push(InviteUserPage.path),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: AppColors.white,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: AppFonts.bodyMedium(color: AppColors.inkStrong),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search by name or role...',
                hintStyle: AppFonts.bodyMedium(color: AppColors.textFieldHint),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.mutedLight,
                  size: 22,
                ),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.inkStrong),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Active',
                  selected: _filterTab == _UserFilterTab.active,
                  onTap: () =>
                      setState(() => _filterTab = _UserFilterTab.active),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Inactive',
                  selected: _filterTab == _UserFilterTab.inactive,
                  onTap: () =>
                      setState(() => _filterTab = _UserFilterTab.inactive),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Invited',
                  selected: _filterTab == _UserFilterTab.invited,
                  onTap: () =>
                      setState(() => _filterTab = _UserFilterTab.invited),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _visibleUsers.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE8E8EA),
              ),
              itemBuilder: (context, index) {
                return _UserListTile(user: _visibleUsers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _SettingsDrawerSelection { personalProfile, users, company, metadata }

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
    required this.selection,
    required this.onExit,
    required this.onPersonalProfile,
    required this.onUsers,
    required this.onCompany,
    required this.onMetadata,
  });

  final _SettingsDrawerSelection selection;
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
                    selected:
                        selection == _SettingsDrawerSelection.personalProfile,
                    onTap: onPersonalProfile,
                  ),
                  _sidebarNavTile(
                    title: 'Users',
                    iconAsset: 'assets/images/public.png',
                    selected: selection == _SettingsDrawerSelection.users,
                    onTap: onUsers,
                  ),
                  _sidebarNavTile(
                    title: 'Company Settings',
                    iconAsset: 'assets/images/company.png',
                    selected: selection == _SettingsDrawerSelection.company,
                    onTap: onCompany,
                  ),
                  _sectionLabelCaps('CUSTOMISATION'),
                  _sidebarNavTile(
                    title: 'Meta Data',
                    iconAsset: 'assets/images/database (1).png',
                    selected: selection == _SettingsDrawerSelection.metadata,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFF0F172A) : AppColors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFD1D5DB),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppFonts.labelLarge(
                color: selected ? AppColors.white : const Color(0xFF9CA3AF),
              ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({required this.user});

  final _UserRowData user;

  static (String label, Color fg, Color border) _badgeStyle(
    _UserDirectoryStatus s,
  ) {
    switch (s) {
      case _UserDirectoryStatus.active:
        return ('ACTIVE', const Color(0xFF16A34A), const Color(0xFF86EFAC));
      case _UserDirectoryStatus.inactive:
        return ('INACTIVE', const Color(0xFF9CA3AF), const Color(0xFFD1D5DB));
      case _UserDirectoryStatus.invited:
        return ('INVITED', const Color(0xFFD97706), const Color(0xFFFCD34D));
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badgeStyle(user.directoryStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _UserAvatar(user: user),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  user.role,
                  style: AppFonts.bodyMedium(color: const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Text(
                  user.createdByLabel,
                  style: AppFonts.bodySmall(color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badge.$3, width: 1),
            ),
            child: Text(
              badge.$1,
              style: AppFonts.labelSmall(color: badge.$2).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final _UserRowData user;

  static const _avatarColors = <Color>[
    Color(0xFF93C5FD),
    Color(0xFFFCA5A5),
    Color(0xFF86EFAC),
    Color(0xFFFCD34D),
    Color(0xFFC4B5FD),
    Color(0xFF5EEAD4),
  ];

  String get _initials {
    final parts = user.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    final a = parts[0].isNotEmpty ? parts[0][0] : '';
    final b = parts[1].isNotEmpty ? parts[1][0] : '';
    return ('$a$b').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    if (!user.useInitialsAvatar) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFE5E7EB),
        child: Icon(Icons.person_rounded, size: 28, color: AppColors.muted),
      );
    }
    final hash = user.name.hashCode.abs();
    final bg = _avatarColors[hash % _avatarColors.length];
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      child: Text(
        _initials,
        style: AppFonts.titleSmall(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
      ),
    );
  }
}
