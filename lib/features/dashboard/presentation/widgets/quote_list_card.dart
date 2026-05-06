import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';

class QuoteListCard extends StatelessWidget {
  const QuoteListCard({
    super.key,
    required this.quoteName,
    required this.quoteNumber,
    required this.onOpen,
    this.isOpening = false,
  });

  final String quoteName;
  final String quoteNumber;
  final VoidCallback onOpen;
  final bool isOpening;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandPrimaryContainer,
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quoteName,
                      style: AppFonts.titleLarge(color: AppColors.ink)
                          .copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quote no: $quoteNumber',
                      style: AppFonts.bodyMedium(color: AppColors.muted)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              isOpening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedLight,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholders matching [QuoteListCard] layout (dashboard list load).
class QuoteListLoadingSkeleton extends StatelessWidget {
  const QuoteListLoadingSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == itemCount - 1 ? 0 : 10),
          child: const _QuoteListCardSkeleton(),
        ),
      ),
    );
  }
}

class _QuoteListCardSkeleton extends StatelessWidget {
  const _QuoteListCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const AppSkeletonCircle(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonLine(height: 18, widthFactor: 0.88),
                  const SizedBox(height: 10),
                  AppSkeletonLine(height: 14, widthFactor: 0.52),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppSkeletonBox(height: 22, width: 22, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}
