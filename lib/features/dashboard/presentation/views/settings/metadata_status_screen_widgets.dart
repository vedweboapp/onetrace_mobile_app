import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Sub-header under metadata status app bars.
class MetadataStatusSectionLabel extends StatelessWidget {
  const MetadataStatusSectionLabel({
    super.key,
    this.label = 'SYSTEM METADATA • STATUS OPTIONS',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Text(
        label,
        style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF)).copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Centered empty state for pin / job status lists.
class MetadataStatusEmptyState extends StatelessWidget {
  const MetadataStatusEmptyState({
    super.key,
    required this.description,
    this.title = 'No items yet',
    this.icon = Icons.checklist_rounded,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE8EAED)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: 40, color: const Color(0xFFB8BEC8)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 22),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: const Color(0xFF9CA3AF),
              ).copyWith(fontSize: 14, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width bottom CTA for adding a status option.
class MetadataStatusAddButton extends StatelessWidget {
  const MetadataStatusAddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.inkStrong,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              '+ Add Status',
              style: AppFonts.bodyLarge(
                color: AppColors.white,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile avatar for settings sub-pages (matches dashboard toolbar).
class SettingsToolbarAvatar extends StatelessWidget {
  const SettingsToolbarAvatar({super.key, this.imageUrl, this.onTap});

  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    Widget avatar;
    if (url != null && url.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFE5E7EB),
        backgroundImage: NetworkImage(url),
      );
    } else {
      avatar = const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFE5E7EB),
        child: Icon(
          Icons.person_rounded,
          size: 22,
          color: AppColors.textFieldHint,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      ),
    );
  }
}

/// Dashed info card shown above the add button on status screens.
class MetadataVisibilityInfoCard extends StatelessWidget {
  const MetadataVisibilityInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          radius: const Radius.circular(16),
          strokeWidth: 1.5,
          color: const Color(0xFF93C5FD),
          dashPattern: const [6, 4],
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Visibility',
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These statuses will be available across all projects '
                      'within the System Metadata context.',
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF6B7280),
                      ).copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
