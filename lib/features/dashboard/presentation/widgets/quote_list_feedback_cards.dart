import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

class QuoteListErrorCard extends StatelessWidget {
  const QuoteListErrorCard({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Failed to load quote data',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class QuoteListEmptyCard extends StatelessWidget {
  const QuoteListEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No quote data found.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
