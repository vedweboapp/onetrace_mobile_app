import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';
import 'package:red5/features/material_requests/data/material_requests_api_client.dart';

/// Operative dispatch detail with a **Received** confirmation action.
class EmployeeDispatchDetailPage extends ConsumerStatefulWidget {
  const EmployeeDispatchDetailPage({super.key, required this.dispatchId});

  static const pathPrefix = '/employee-role/dispatches';
  static const name = 'employee-dispatch-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String dispatchId;

  @override
  ConsumerState<EmployeeDispatchDetailPage> createState() =>
      _EmployeeDispatchDetailPageState();
}

class _EmployeeDispatchDetailPageState
    extends ConsumerState<EmployeeDispatchDetailPage> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _itemsBg = Color(0xFFF9FAFB);

  MaterialDispatchRead? _detail;
  var _loading = true;
  var _markingReceived = false;
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
      final detail = await api.fetchDispatchById(widget.dispatchId.trim());
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
          genericFallback: 'Could not load dispatch.',
        );
      });
    }
  }

  Future<void> _onReceived() async {
    if (_markingReceived) return;
    setState(() => _markingReceived = true);
    // Receive confirmation endpoint is not finalized; acknowledge locally for now.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _markingReceived = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as received')),
    );
    context.pop(true);
  }

  Widget _infoRow(String label, String value) {
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
          detail?.code ?? 'Dispatch',
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
                              Text(
                                'BASIC INFO',
                                style: AppFonts.labelMedium(color: _muted)
                                    .copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _infoRow(
                                'Dispatch To',
                                detail.dispatchTo?.trim().isNotEmpty == true
                                    ? detail.dispatchTo!.trim()
                                    : '—',
                              ),
                              if (detail.statusName?.trim().isNotEmpty == true)
                                _infoRow('Status', detail.statusName!.trim()),
                              _infoRow(
                                'Dispatch Date',
                                detail.dispatchDate == null
                                    ? '—'
                                    : _dateFormat.format(detail.dispatchDate!),
                              ),
                              _infoRow(
                                'Material Request',
                                detail.materialRequestCode?.trim().isNotEmpty ==
                                        true
                                    ? detail.materialRequestCode!.trim()
                                    : '—',
                              ),
                              if (detail.notes?.trim().isNotEmpty == true)
                                _infoRow('Notes', detail.notes!.trim()),
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
                                style: AppFonts.labelMedium(color: _muted)
                                    .copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (detail.items.isEmpty)
                                Text(
                                  'No items',
                                  style: AppFonts.bodyMedium(color: _muted),
                                )
                              else
                                for (final item in detail.items)
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
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
                                              if (item.sku != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.sku!,
                                                  style: AppFonts.bodySmall(
                                                    color: _muted,
                                                  ),
                                                ),
                                              ],
                                              if (item.isExtra) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Extra item',
                                                  style: AppFonts.labelMedium(
                                                    color: const Color(
                                                      0xFFC2410C,
                                                    ),
                                                  ).copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          item.quantityLabel,
                                          style: AppFonts.bodyMedium(
                                            color: _muted,
                                          ).copyWith(
                                            fontWeight: FontWeight.w700,
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
      bottomNavigationBar: detail == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _markingReceived ? null : _onReceived,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkStrong,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _markingReceived
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.white,
                            ),
                          )
                        : Text(
                            'Received',
                            style: AppFonts.titleMedium(color: AppColors.white)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ),
            ),
    );
  }
}
