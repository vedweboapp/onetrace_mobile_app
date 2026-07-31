import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';
import 'package:red5/features/material_requests/data/material_requests_api_client.dart';

/// Operative return-request detail (items + summary).
class EmployeeReturnRequestDetailPage extends ConsumerStatefulWidget {
  const EmployeeReturnRequestDetailPage({
    super.key,
    required this.returnRequestId,
  });

  static const pathPrefix = '/employee-role/return-requests';
  static const name = 'employee-return-request-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String returnRequestId;

  @override
  ConsumerState<EmployeeReturnRequestDetailPage> createState() =>
      _EmployeeReturnRequestDetailPageState();
}

class _EmployeeReturnRequestDetailPageState
    extends ConsumerState<EmployeeReturnRequestDetailPage> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);

  MaterialReturnRequestRead? _detail;
  var _loading = true;
  String? _errorMessage;

  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(materialRequestsApiClientProvider);
      final detail =
          await api.fetchReturnRequestById(widget.returnRequestId.trim());
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          error,
          genericFallback: 'Could not load return request.',
        );
      });
    }
  }

  Widget _summaryChip(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppFonts.labelMedium(color: _muted).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

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
          detail?.code ?? 'Return Request',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppFonts.bodyMedium(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : detail == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  (detail.statusName ?? 'Return request')
                                      .trim(),
                                  style: AppFonts.labelMedium(
                                    color: const Color(0xFFC2410C),
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _summaryChip('Request', detail.code),
                                  _summaryChip(
                                    'Items',
                                    '${detail.itemCount}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _summaryChip(
                                    'Quantity',
                                    '${detail.totalQuantity}',
                                  ),
                                  _summaryChip(
                                    'Date',
                                    detail.requestedDate == null
                                        ? '—'
                                        : _dateFormat
                                            .format(detail.requestedDate!),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ITEMS',
                          style: AppFonts.labelMedium(color: _muted).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (detail.items.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                            ),
                            child: Text(
                              'No items on this return request',
                              style: AppFonts.bodyMedium(color: _muted),
                            ),
                          )
                        else
                          for (final item in detail.items)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: _muted,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          style: AppFonts.bodyMedium(
                                            color: AppColors.inkStrong,
                                          ).copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.displayQuantity,
                                          style: AppFonts.bodySmall(
                                            color: _muted,
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
    );
  }
}
