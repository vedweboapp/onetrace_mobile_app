import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_bar_styles.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/theme/app_layout.dart';
import 'package:red5/core/widgets/app_screen_stack.dart';
import 'package:red5/features/dashboard/data/quote_composite_models.dart';
import 'package:red5/features/dashboard/presentation/widgets/composite_group_list_tile.dart';
import 'package:red5/features/dashboard/presentation/widgets/composite_item_detail_card.dart';

export 'package:red5/features/dashboard/data/quote_composite_models.dart';
export 'package:red5/features/dashboard/data/quote_composite_parser.dart';

/// Lists composite item groups for a quote; opens [QuoteCompositeGroupItemsPage] per group.
class QuoteCompositeItemGroupsPage extends StatelessWidget {
  const QuoteCompositeItemGroupsPage({
    super.key,
    required this.quoteTitle,
    required this.groups,
  });

  /// GoRouter path — open from dashboard via `context.push(QuoteCompositeItemGroupsPage.path)`.
  static const path = '/composite-item-groups';
  static const name = 'compositeItemGroups';

  final String quoteTitle;
  final List<QuoteCompositeItemGroup> groups;

  @override
  Widget build(BuildContext context) {
    final listTopPad = AppLayout.bodyTopBelowAppBar(context);
    return Scaffold(
      backgroundColor: AppColors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBarStyles.transparent(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Composite item groups',
              style:
                  AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
            ),
            Text(
              quoteTitle,
              style: AppFonts.bodyMedium(color: AppColors.muted).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
      ),
      body: AppScreenStack(
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, listTopPad, 16, 24),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final g = groups[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CompositeGroupListTile(
                title: g.title,
                subtitle:
                    '${g.items.length} composite ${g.items.length == 1 ? 'item' : 'items'}',
                onTap: () {
                  context.push(
                    QuoteCompositeGroupItemsPage.path,
                    extra: <String, dynamic>{
                      'quoteTitle': quoteTitle,
                      'group': g,
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Line items inside one composite group.
class QuoteCompositeGroupItemsPage extends StatelessWidget {
  const QuoteCompositeGroupItemsPage({
    super.key,
    required this.quoteTitle,
    required this.group,
  });

  /// GoRouter path — pass `extra`: `quoteTitle` (String), `group` ([QuoteCompositeItemGroup] or JSON map).
  static const path = '/quotes/composite/item-group';
  static const name = 'quoteCompositeItemGroup';

  final String quoteTitle;
  final QuoteCompositeItemGroup group;

  static String _fmtMoney(double? v) {
    if (v == null) return '—';
    return '£${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final listTopPad = AppLayout.bodyTopBelowAppBar(context);
    return Scaffold(
      backgroundColor: AppColors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBarStyles.transparent(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              group.title,
              style:
                  AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
            ),
            Text(
              quoteTitle,
              style: AppFonts.bodyMedium(color: AppColors.muted).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
      ),
      body: AppScreenStack(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, listTopPad, 16, 24),
          children: [
            Text(
              'Composite items (${group.items.length})',
              style: AppFonts.titleMedium(color: AppColors.ink).copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            for (final item in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CompositeItemDetailCard(
                  name: item.name,
                  description: item.description,
                  sku: item.sku,
                  quantity: item.quantity,
                  totalLabel: _fmtMoney(item.total),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
