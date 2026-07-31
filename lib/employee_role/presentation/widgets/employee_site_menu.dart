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

  /// More menu short card — Job Shift, Reports, Material Required.
  static List<EmployeeSiteMenuSection> buildSections({
    VoidCallback? onEarnings,
    VoidCallback? onReport,
    VoidCallback? onMaterialRequests,
  }) {
    return [
      EmployeeSiteMenuSection(
        title: '',
        items: [
          EmployeeSiteMenuItem(
            label: 'Earnings',
            icon: Icons.payments_rounded,
            onTap: onEarnings,
          ),
          EmployeeSiteMenuItem(
            label: 'Reports',
            icon: Icons.bar_chart_rounded,
            onTap: onReport,
          ),
          EmployeeSiteMenuItem(
            label: 'Material Required',
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
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final section in sections)
                for (final item in section.items)
                  _CompactMenuTile(
                    item: item,
                    onTap: () {
                      Navigator.of(context).pop();
                      item.onTap?.call();
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMenuTile extends StatelessWidget {
  const _CompactMenuTile({required this.item, required this.onTap});

  final EmployeeSiteMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.isDestructive ? AppColors.error : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0xFFF3F4F6),
          highlightColor: const Color(0xFFF3F4F6),
          splashColor: const Color(0xFFE5E7EB),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppFonts.bodyMedium(
                      color: color,
                    ).copyWith(fontWeight: FontWeight.w800, fontSize: 14),
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
