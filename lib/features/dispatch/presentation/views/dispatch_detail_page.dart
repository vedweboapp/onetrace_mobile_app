import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dispatch/data/dispatch_models.dart';
import 'package:red5/features/dispatch/presentation/widgets/dispatch_widgets.dart';

/// Dispatch detail summary (UI preview until API is available).
class DispatchDetailPage extends StatefulWidget {
  const DispatchDetailPage({super.key, required this.dispatchId});

  static const pathPrefix = '/dispatches';
  static const name = 'dispatch-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String dispatchId;

  @override
  State<DispatchDetailPage> createState() => _DispatchDetailPageState();
}

class _DispatchDetailPageState extends State<DispatchDetailPage> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _itemsBg = Color(0xFFF9FAFB);

  late final DispatchDetail _detail;

  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _detail = DispatchMockData.detailForId(widget.dispatchId);
  }

  void _onDispatch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispatch confirmed')),
    );
  }

  Widget _infoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppFonts.labelMedium(color: _muted).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          if (isStatus)
            DispatchStatusBadge(status: _detail.status)
          else
            Text(
              value,
              style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.inkStrong,
        ),
        title: Text(
          _detail.dispatchCode,
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BASIC INFO',
                        style: AppFonts.labelMedium(color: _muted).copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _infoRow('Dispatch To', _detail.dispatchTo),
                      _infoRow('Status', _detail.status.label, isStatus: true),
                      _infoRow(
                        'Dispatch Date',
                        _dateFormat.format(_detail.dispatchDate),
                      ),
                      _infoRow(
                        'Material Request ID',
                        _detail.materialRequestId,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _itemsBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ITEMS',
                        style: AppFonts.labelMedium(color: _muted).copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final item in _detail.items)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: AppFonts.bodyMedium(
                                    color: AppColors.inkStrong,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Text(
                                item.quantityLabel,
                                style: AppFonts.titleMedium(
                                  color: AppColors.inkStrong,
                                ).copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _onDispatch,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Dispatch',
                    style: AppFonts.titleMedium(color: AppColors.white).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
