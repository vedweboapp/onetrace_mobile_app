import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/items/data/item_models.dart';
import 'package:red5/features/items/data/items_api_client.dart';
import 'package:red5/features/composite_items/presentation/view/add_composite_item_page.dart';
import 'package:red5/features/items/presentation/views/add_item_page.dart';

/// Detail view for one catalog item — `GET /api/v1/item/{id}/`.
class ItemDetailPage extends ConsumerStatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});

  static const pathPrefix = '/catalog/items';
  static const name = 'item-detail';

  static String pathFor(String id) => '$pathPrefix/$id';

  final String itemId;

  @override
  ConsumerState<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends ConsumerState<ItemDetailPage> {
  ItemDetailModel? _item;
  bool _isLoading = true;
  String? _error;

  static const _labelGrey = Color(0xFF9CA3AF);
  static const _chipBg = Color(0xFFF1F1F2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.itemId.trim();
    if (id.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid item id';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(itemsApiClientProvider);
      final data = await api.fetchItemDetail(id);
      if (!mounted) return;
      setState(() {
        _item = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load item details',
        );
      });
    }
  }

  String _fmtQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2);

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Text(
        text,
        style: AppFonts.titleMedium(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 20),
      ),
    );
  }

  Widget _typeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6E6E7)),
      ),
      child: Text(
        label,
        style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppFonts.labelMedium(color: _labelGrey).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.65,
        fontSize: 11,
      ),
    );
  }

  Widget _fieldValue(String text) {
    return Text(
      text.trim().isEmpty ? '—' : text.trim(),
      style: AppFonts.bodyMedium(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w500, fontSize: 16, height: 1.25),
    );
  }

  Widget _fullWidthField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        _fieldValue(value),
      ],
    );
  }

  Widget _halfRow(String leftLabel, String leftValue, String rightLabel, String rightValue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel(leftLabel),
              const SizedBox(height: 6),
              _fieldValue(leftValue),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel(rightLabel),
              const SizedBox(height: 6),
              _fieldValue(rightValue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recordBlock(String label, String line1, {String? line2}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        _fieldValue(line1),
        if (line2 != null && line2.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            line2.trim(),
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w500, fontSize: 15, height: 1.25),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(ItemDetailModel d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _sectionHeader('Basic Info'),
        const SizedBox(height: 4),
        _typeChip(d.itemTypeLabel),
        const SizedBox(height: 18),
        _fullWidthField('Item name', d.name),
        const SizedBox(height: 16),
        _halfRow('SKU', d.sku, 'Reorder quantity', _fmtQty(d.reorderQuantity)),
        const SizedBox(height: 16),
        _halfRow(
          'Quantity',
          _fmtQty(d.quantity),
          'Item type',
          d.itemTypeLabel,
        ),
        const SizedBox(height: 16),
        _halfRow(
          'Cost price',
          _fmtMoney(d.costPrice),
          'Selling price',
          _fmtMoney(d.sellPrice),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        const SizedBox(height: 12),
        if (d.isComposite) ...[
          _sectionHeader('Components'),
          const SizedBox(height: 4),
          if (d.components.isEmpty)
            Text(
              'No component lines in the response.',
              style: AppFonts.bodyMedium(color: AppColors.muted).copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            )
          else
            ...d.components.map((c) {
              final sku = c.sku.trim().isEmpty ? '—' : c.sku.trim();
              final sub = 'SKU: $sku · Qty: ${_fmtQty(c.quantity)}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _recordBlock(
                  c.itemName.trim().isEmpty ? 'Component' : c.itemName.trim(),
                  sub,
                ),
              );
            }),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
          const SizedBox(height: 12),
        ],
        _sectionHeader('Record'),
        const SizedBox(height: 4),
        _fullWidthField('Created at', d.createdAtDisplay),
        const SizedBox(height: 16),
        _fullWidthField('Updated at', d.updatedAtDisplay),
        const SizedBox(height: 16),
        _recordBlock(
          'Created by',
          d.createdByUsername.isNotEmpty ? d.createdByUsername : '—',
          line2: d.createdByEmail.isNotEmpty ? d.createdByEmail : null,
        ),
        const SizedBox(height: 16),
        _recordBlock(
          'Modified by',
          d.hasModifiedBy
              ? (d.modifiedByUsername.isNotEmpty
                    ? d.modifiedByUsername
                    : (d.modifiedByEmail.isNotEmpty ? d.modifiedByEmail : '—'))
              : '—',
          line2: d.hasModifiedBy &&
                  d.modifiedByUsername.isNotEmpty &&
                  d.modifiedByEmail.isNotEmpty
              ? d.modifiedByEmail
              : null,
        ),
      ],
    );
  }

  Future<void> _onEditTap() async {
    final item = _item;
    if (item == null) return;
    if (item.isComposite) {
      await context.push<Object?>(
        AddCompositeItemPage.pathForEdit(widget.itemId),
        extra: item,
      );
    } else {
      await context.push<Object?>(
        AddItemPage.pathForEdit(widget.itemId),
        extra: item,
      );
    }
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _item?.name.isNotEmpty == true ? _item!.name : 'Item';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: const Color(0xFFF1F1F2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isLoading || _item == null ? null : _onEditTap,
                child:  Padding(
                  padding: EdgeInsets.all(10),
                  child: Image.asset(
                    "assets/images/edit_icon.png",
                    height: 16,
                    width: 16,
                    color: AppColors.inkStrong,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
      ),
      body: _isLoading
          ? Center(
              child: const AppSkeletonScreenBody(
                scrollable: false,
                toastBlockCount: 4,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _item == null
          ? const SizedBox.shrink()
          : _buildBody(_item!),
    );
  }
}
