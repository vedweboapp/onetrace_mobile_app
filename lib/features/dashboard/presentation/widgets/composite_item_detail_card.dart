import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

class CompositeItemDetailCard extends StatelessWidget {
  const CompositeItemDetailCard({
    super.key,
    required this.name,
    this.description,
    this.sku,
    this.quantity,
    this.totalLabel,
  });

  final String name;
  final String? description;
  final String? sku;
  final int? quantity;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
            if (description != null && description!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description!.trim(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (sku != null && sku!.trim().isNotEmpty)
                  Text(
                    'SKU: $sku',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                if (quantity != null)
                  Text(
                    'Qty: $quantity',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                if (totalLabel != null)
                  Text(
                    'Total: $totalLabel',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
