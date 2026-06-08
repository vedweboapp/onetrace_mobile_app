import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/reports/data/employee_reports_data.dart';

/// Inventory and status for a single technician site.
class EmployeeSiteDetailPage extends StatelessWidget {
  const EmployeeSiteDetailPage({
    super.key,
    required this.site,
  });

  final EmployeeReportSite site;

  static const path = '/employee-role/sites/detail';
  static const name = 'employee-site-detail';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 18, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    color: AppColors.inkStrong,
                  ),
                  Expanded(
                    child: Text(
                      'Site Detail',
                      textAlign: TextAlign.center,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                children: [
                  _SiteHeader(site: site),
                  const SizedBox(height: 22),
                  Text(
                    'Site Inventory',
                    style: AppFonts.titleMedium(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  _SiteInventoryCard(items: site.inventory),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({required this.site});

  final EmployeeReportSite site;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                site.name,
                style: AppFonts.headlineSmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 26),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                site.status,
                style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Last Updated: ${site.lastUpdated}',
          style: AppFonts.bodySmall(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SiteInventoryCard extends StatelessWidget {
  const _SiteInventoryCard({required this.items});

  final List<EmployeeReportInventoryItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _InventoryRow(item: items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 18, endIndent: 18),
          ],
        ],
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item});

  final EmployeeReportInventoryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 20, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                if (item.inTransitLabel != null)
                  Text(
                    item.inTransitLabel!,
                    style: AppFonts.bodySmall(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w700),
                  )
                else if (item.stockStatus != null)
                  RichText(
                    text: TextSpan(
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                      children: [
                        const TextSpan(text: 'Stock Status: '),
                        TextSpan(
                          text: item.stockStatus!.label,
                          style: TextStyle(
                            color: item.stockStatus!.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.quantity,
            style: AppFonts.titleSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
