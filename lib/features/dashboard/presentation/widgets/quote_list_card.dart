import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quote no: $quoteNumber',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
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
