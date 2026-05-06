import 'package:flutter/material.dart';
import 'package:red5/core/constants/app_image_string.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

class AppUnderDevelopmentView extends StatelessWidget {
  const AppUnderDevelopmentView({
    super.key,
    this.title = 'Working on this page',
    this.message = 'This section is under development.\nCheck back soon for updates.',
    this.showSkeletonLines = true,
  });

  final String title;
  final String message;
  final bool showSkeletonLines;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: const Color(0xFFF1F1F2),
                border: Border.all(color: const Color(0xFFE6E6E7)),
              ),
              child: Center(
                child: Image.asset(
                  AppImageString.hammerPng,
                  width: 34,
                  height: 34,
                  color: const Color(0xFFB8B8BC),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 34),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: AppColors.muted,
              ).copyWith(height: 1.45, fontSize: 15),
            ),
            if (showSkeletonLines) ...[
              const SizedBox(height: 30),
              Container(
                height: 20,
                width: 340,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDEF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 20,
                width: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDEF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 20,
                width: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDEF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
