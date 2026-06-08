import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/presentation/views/settings/pin_status_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/tags_settings_page.dart';

/// Intermediate "Meta data" page that lists the metadata categories
/// for a single module (e.g. Projects -> Pin Status, Quotations -> Tags).
class _ModuleMetadataView extends StatelessWidget {
  const _ModuleMetadataView({required this.entries});

  final List<_ModuleMetadataEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Meta data',
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Text(
              'SYSTEM METADATA',
              style: AppFonts.labelMedium(
                color: const Color(0xFF9CA3AF),
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),
            for (final entry in entries) ...[
              _ConfigurationTile(
                icon: entry.icon,
                title: entry.title,
                onTap: () => context.push(entry.route),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModuleMetadataEntry {
  const _ModuleMetadataEntry({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;
}

class _ConfigurationTile extends StatelessWidget {
  const _ConfigurationTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      shadowColor: AppColors.shadowCard,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF3F4F6),
                ),
                child: Icon(icon, size: 18, color: AppColors.inkStrong),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.bodyLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CONFIGURATION',
                      style: AppFonts.labelSmall(color: const Color(0xFF9CA3AF))
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectsMetadataPage extends StatelessWidget {
  const ProjectsMetadataPage({super.key});

  static const path = '/settings/metadata/projects';
  static const name = 'settings-metadata-projects';

  @override
  Widget build(BuildContext context) {
    return _ModuleMetadataView(
      entries: const [
        _ModuleMetadataEntry(
          icon: Icons.push_pin_rounded,
          title: 'Pin Status',
          route: PinStatusSettingsPage.path,
        ),
      ],
    );
  }
}

class QuotationsMetadataPage extends StatelessWidget {
  const QuotationsMetadataPage({super.key});

  static const path = '/settings/metadata/quotations';
  static const name = 'settings-metadata-quotations';

  @override
  Widget build(BuildContext context) {
    return _ModuleMetadataView(
      entries: const [
        _ModuleMetadataEntry(
          icon: Icons.local_offer_rounded,
          title: 'Tags',
          route: TagsSettingsPage.path,
        ),
      ],
    );
  }
}
