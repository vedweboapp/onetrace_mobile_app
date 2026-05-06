import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

class QuotePaginationBar extends StatelessWidget {
  const QuotePaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.onPrev,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          OutlinedButton(onPressed: isLoading ? null : onPrev, child: const Text('Prev')),
          const Spacer(),
          Text(
            'Page $currentPage / $totalPages',
            style: AppFonts.bodyMedium(color: AppColors.paginationText)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          OutlinedButton(onPressed: isLoading ? null : onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}
