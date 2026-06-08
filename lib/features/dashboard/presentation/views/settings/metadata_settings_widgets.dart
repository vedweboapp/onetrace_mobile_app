import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Single row inside the system metadata card.
class SystemMetadataRow {
  const SystemMetadataRow({
    required this.icon,
    required this.title,
    required this.moduleLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String moduleLabel;
  final VoidCallback onTap;
}

/// "SYSTEM METADATA" section with one grouped card of options.
class SystemMetadataCard extends StatelessWidget {
  const SystemMetadataCard({super.key, required this.rows});

  final List<SystemMetadataRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFE5E7EB)),
              _SystemMetadataRowTile(row: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SystemMetadataRowTile extends StatelessWidget {
  const _SystemMetadataRowTile({required this.row});

  final SystemMetadataRow row;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: row.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF3),
                  shape: BoxShape.circle,
                ),
                child: Icon(row.icon, size: 20, color: AppColors.inkStrong),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      style: AppFonts.bodyLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      row.moduleLabel.toUpperCase(),
                      style: AppFonts.labelSmall(color: const Color(0xFF9CA3AF))
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
