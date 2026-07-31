import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/reports/data/employee_reports_data.dart';

class EmployeeReportProductDetailPage extends StatelessWidget {
  const EmployeeReportProductDetailPage({
    super.key,
    required this.product,
  });

  final EmployeeReportProduct product;

  static const path = '/employee-role/reports/product';
  static const name = 'employee-report-product-detail';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _DetailAppBar(
              title: product.name,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _ProductIdentityCard(product: product),
                  const SizedBox(height: 12),
                  _QuantitySummaryCard(quantity: product.totalQuantity),
                  const SizedBox(height: 22),
                  Text(
                    'Site Distribution',
                    style: AppFonts.titleMedium(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ...product.allocations.map(
                    (allocation) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SiteAllocationCard(allocation: allocation),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 18, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.inkStrong,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.titleSmall(
                color: AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductIdentityCard extends StatelessWidget {
  const _ProductIdentityCard({required this.product});

  final EmployeeReportProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.muted,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppFonts.titleMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last Updated: ${product.lastUpdated}',
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantitySummaryCard extends StatelessWidget {
  const _QuantitySummaryCard({required this.quantity});

  final String quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUANTITY',
            style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quantity,
            style: AppFonts.headlineSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 32),
          ),
        ],
      ),
    );
  }
}

class _SiteAllocationCard extends StatelessWidget {
  const _SiteAllocationCard({required this.allocation});

  final EmployeeReportSiteAllocation allocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: AppColors.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allocation.siteName,
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quantity Allocated: ${allocation.quantityAllocated}',
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
