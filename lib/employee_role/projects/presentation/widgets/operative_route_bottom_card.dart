import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/projects/data/operative_map_route_service.dart';

/// Rapido-style route summary shown over the operative map.
class OperativeRouteBottomCard extends StatelessWidget {
  const OperativeRouteBottomCard({
    super.key,
    required this.route,
    required this.onClose,
    this.isLoading = false,
    this.onOpenExternalNavigation,
  });

  final OperativeRoutePlan? route;
  final VoidCallback onClose;
  final bool isLoading;
  final VoidCallback? onOpenExternalNavigation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Material(
          elevation: 10,
          shadowColor: const Color(0x33000000),
          borderRadius: BorderRadius.circular(18),
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: Color(0xFF5E4BFF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isLoading
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calculating route…',
                              style: AppFonts.titleSmall(
                                color: AppColors.inkStrong,
                              ).copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            const LinearProgressIndicator(minHeight: 3),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route to site',
                              style: AppFonts.labelSmall(
                                color: AppColors.muted,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              route?.destinationTitle ?? 'Destination',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.titleSmall(
                                color: AppColors.inkStrong,
                              ).copyWith(fontWeight: FontWeight.w900, height: 1.15),
                            ),
                            if (route?.destinationSubtitle != null &&
                                route!.destinationSubtitle!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                route!.destinationSubtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.bodySmall(
                                  color: AppColors.muted,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                            if (route != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${route!.durationLabel} · ${route!.distanceLabel}',
                                style: AppFonts.labelLarge(
                                  color: const Color(0xFF00A553),
                                ).copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                            if (onOpenExternalNavigation != null &&
                                route != null &&
                                !isLoading) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: FilledButton.icon(
                                  onPressed: onOpenExternalNavigation,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF00A553),
                                    foregroundColor: AppColors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.navigation_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Start navigation',
                                    style: AppFonts.labelLarge(
                                      color: AppColors.white,
                                    ).copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.muted,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
