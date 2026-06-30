import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

final class EmployeeSiteMenuSection {
  const EmployeeSiteMenuSection({required this.title, required this.items});

  final String title;
  final List<EmployeeSiteMenuItem> items;
}

final class EmployeeSiteMenuItem {
  const EmployeeSiteMenuItem({
    required this.label,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;
}

abstract final class EmployeeSiteMenu {
  const EmployeeSiteMenu._();

  /// More menu short card — Job sheet, Report, Site, Material Requests.
  static List<EmployeeSiteMenuSection> buildSections({
    VoidCallback? onJobSheet,
    VoidCallback? onReport,
    VoidCallback? onSite,
    VoidCallback? onMaterialRequests,
  }) {
    return [
      EmployeeSiteMenuSection(
        title: '',
        items: [
          EmployeeSiteMenuItem(
            label: 'Job sheet',
            icon: Icons.assignment_outlined,
            onTap: onJobSheet,
          ),
          EmployeeSiteMenuItem(
            label: 'Report',
            icon: Icons.summarize_outlined,
            onTap: onReport,
          ),
          EmployeeSiteMenuItem(
            label: 'Site',
            icon: Icons.location_on_outlined,
            onTap: onSite,
          ),
          EmployeeSiteMenuItem(
            label: 'Material Requests',
            icon: Icons.inventory_2_outlined,
            onTap: onMaterialRequests,
          ),
        ],
      ),
    ];
  }

  /// Shows a compact menu card above the bottom-right hamburger button.
  static Future<void> showShortCard(
    BuildContext context, {
    required List<EmployeeSiteMenuSection> sections,
    double bottomOffset = 88,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss menu',
      barrierColor: const Color(0x55000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, _, _) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Positioned(
                right: 12,
                bottom: bottomOffset,
                child: _EmployeeSiteShortCard(sections: sections),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
            alignment: Alignment.bottomRight,
            child: child,
          ),
        );
      },
    );
  }

}

class EmployeeSiteMenuButton extends StatelessWidget {
  const EmployeeSiteMenuButton({
    super.key,
    required this.label,
    required this.sections,
    this.active = false,
    this.bottomOffset = 88,
  });

  final String label;
  final List<EmployeeSiteMenuSection> sections;
  final bool active;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.inkStrong : AppColors.muted;

    return InkWell(
      onTap: () {
        EmployeeSiteMenu.showShortCard(
          context,
          sections: sections,
          bottomOffset: bottomOffset,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppFonts.labelSmall(
                color: color,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeSiteShortCard extends StatelessWidget {
  const _EmployeeSiteShortCard({required this.sections});

  final List<EmployeeSiteMenuSection> sections;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 12,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290, maxHeight: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
              child: Row(
                children: [
                  const Icon(Icons.menu, size: 20, color: AppColors.inkStrong),
                  const SizedBox(width: 8),
                  Text(
                    'More',
                    style: AppFonts.titleSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                children: [
                  for (final section in sections) ...[
                    _MenuSection(section: section, compact: true),
                    if (section != sections.last) const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.section, this.compact = false});

  final EmployeeSiteMenuSection section;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showTitle = section.title.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              compact ? 2 : 6,
              10,
              compact ? 4 : 8,
            ),
            child: Text(
              section.title.toUpperCase(),
              style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                fontSize: compact ? 9 : null,
              ),
            ),
          ),
        for (final item in section.items)
          _MenuTile(
            item: item,
            compact: compact,
            onTap: () {
              Navigator.of(context).pop();
              item.onTap?.call();
            },
          ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.onTap,
    this.compact = false,
  });

  final EmployeeSiteMenuItem item;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = item.isDestructive ? AppColors.error : AppColors.inkStrong;
    final iconSize = compact ? 32.0 : 38.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: compact ? 7 : 10,
        ),
        child: Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: item.isDestructive
                    ? const Color(0xFFFFF1F1)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, size: compact ? 16 : 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: AppFonts.bodyMedium(color: color).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 13 : null,
                    ),
                  ),
                  if (item.subtitle != null && !compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: compact ? 18 : 22,
              color: item.isDestructive ? AppColors.error : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
