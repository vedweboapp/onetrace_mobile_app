import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_drawing_preview.dart';

/// Card for a job/site drawing level — matches operative home & detail designs UI.
class EmployeeJobDrawingCard extends StatelessWidget {
  const EmployeeJobDrawingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.updatedLabel,
    required this.drawingFileUrl,
    required this.cacheKey,
    required this.onTap,
    this.pins = const [],
  });

  final String title;
  final String subtitle;
  final String updatedLabel;
  final String? drawingFileUrl;
  final String cacheKey;
  final VoidCallback onTap;
  final List<EmployeeJobDrawingPin> pins;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: _DrawingPreview(
                    cacheKey: cacheKey,
                    remoteDrawingUrl: drawingFileUrl,
                    title: title,
                    pins: pins,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.titleSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: AppColors.borderLight.withValues(alpha: 0.9)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        updatedLabel,
                        style: AppFonts.labelSmall(
                          color: AppColors.mutedLight,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
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

class _DrawingPreview extends StatelessWidget {
  const _DrawingPreview({
    required this.cacheKey,
    required this.remoteDrawingUrl,
    required this.title,
    this.pins = const [],
  });

  final String cacheKey;
  final String? remoteDrawingUrl;
  final String title;
  final List<EmployeeJobDrawingPin> pins;

  @override
  Widget build(BuildContext context) {
    return EmployeeJobDrawingPreview(
      cacheKey: cacheKey,
      remoteDrawingUrl: remoteDrawingUrl,
      fallbackTitle: title,
      pins: pins,
    );
  }
}
