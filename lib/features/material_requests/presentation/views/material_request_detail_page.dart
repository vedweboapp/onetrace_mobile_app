import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dispatch/presentation/views/create_dispatch_page.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';
import 'package:red5/features/material_requests/data/material_requests_api_client.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_request_widgets.dart';

/// Material request detail with Overview, Dispatch, and Timeline tabs.
class MaterialRequestDetailPage extends ConsumerStatefulWidget {
  const MaterialRequestDetailPage({super.key, required this.materialRequestId});

  static const pathPrefix = '/material-requests';
  static const name = 'material-request-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String materialRequestId;

  @override
  ConsumerState<MaterialRequestDetailPage> createState() =>
      _MaterialRequestDetailPageState();
}

class _MaterialRequestDetailPageState
    extends ConsumerState<MaterialRequestDetailPage>
    with SingleTickerProviderStateMixin {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFF2563EB);

  late final TabController _tabController;
  MaterialRequestDetail? _detail;
  var _loading = true;
  String? _errorMessage;

  static final _dateTimeFormat = DateFormat('MMM d, yyyy â€¢ hh:mm a');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final id = widget.materialRequestId.trim();
    try {
      final api = ref.read(materialRequestsApiClientProvider);
      final read = await api.fetchMaterialRequestById(id);
      if (!mounted) return;
      setState(() {
        _detail = read.toDetail();
        _loading = false;
      });
    } catch (error) {
      // Fallback for legacy mock ids used in UI previews.
      final fallback = MaterialRequestMockData.listItemById(id) != null
          ? MaterialRequestMockData.detailForId(id)
          : null;
      if (!mounted) return;
      if (fallback != null) {
        setState(() {
          _detail = fallback;
          _loading = false;
        });
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          error,
          genericFallback: 'Could not load material request.',
        );
      });
    }
  }

  Future<void> _onDispatch() async {
    final detail = _detail;
    if (detail == null) return;
    final created = await context.push<bool?>(
      CreateDispatchPage.path,
      extra: CreateDispatchRouteExtra(
        materialRequestId: detail.requestCode,
        dispatchTo: detail.jobs.isNotEmpty
            ? detail.jobs.first.projectName
            : null,
      ),
    );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispatch created')),
    );
  }

  Widget _infoTile(String label, String value) {
    final detail = _detail;
    return Expanded(
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
          if (label.toUpperCase() == 'STATUS' && detail != null)
            MaterialRequestStatusBadge(
              status: detail.status,
              label: detail.statusLabel,
              background: detail.statusBg,
              foreground: detail.statusFg,
            )
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

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _overviewTab() {
    final detail = _detail!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _card(
          child: Row(
            children: [
              _infoTile('Worker', detail.workerName),
              _infoTile('Status', detail.displayStatusLabel),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JOBS',
                style: AppFonts.labelMedium(color: _muted).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              if (detail.jobs.isEmpty)
                Text(
                  'No jobs linked',
                  style: AppFonts.bodyMedium(color: _muted),
                )
              else
                for (var i = 0; i < detail.jobs.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: _divider),
                  Text(
                    detail.jobs[i].jobCode,
                    style: AppFonts.titleMedium(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail.jobs[i].projectName,
                    style: AppFonts.bodyMedium(color: _muted).copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
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
              if (detail.items.isEmpty)
                Text(
                  'No line items',
                  style: AppFonts.bodyMedium(color: _muted),
                )
              else ...[
                _itemsTableHeader(),
                const Divider(height: 1, color: _divider),
                for (final item in detail.items) _itemsTableRow(item),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemsTableHeader() {
    TextStyle style = AppFonts.labelMedium(color: _muted).copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      fontSize: 10,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('ITEM NAME', style: style)),
          Expanded(child: Text('REQUESTED', style: style)),
          Expanded(child: Text('DISPATCHED', style: style)),
          Expanded(child: Text('PENDING', style: style)),
        ],
      ),
    );
  }

  Widget _itemsTableRow(MaterialRequestItemLine item) {
    TextStyle valueStyle = AppFonts.bodySmall(color: AppColors.inkStrong)
        .copyWith(fontWeight: FontWeight.w600, fontSize: 12);
    final pendingStyle = item.highlightPending
        ? valueStyle.copyWith(color: const Color(0xFFDC2626))
        : valueStyle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(item.itemName, style: valueStyle),
          ),
          Expanded(child: Text(item.requestedLabel, style: valueStyle)),
          Expanded(child: Text(item.dispatchedLabel, style: valueStyle)),
          Expanded(child: Text(item.pendingLabel, style: pendingStyle)),
        ],
      ),
    );
  }

  Widget _dispatchTab() {
    final detail = _detail!;
    if (detail.dispatchItems.isEmpty) {
      return Center(
        child: Text(
          'No dispatched items yet',
          style: AppFonts.bodyMedium(color: _muted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        for (final item in detail.dispatchItems)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.itemName,
                    style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                        .copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  item.quantity ?? item.requestedLabel,
                  style: AppFonts.titleMedium(color: AppColors.inkStrong)
                      .copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _timelineTab() {
    final detail = _detail!;
    if (detail.timeline.isEmpty) {
      return Center(
        child: Text(
          'No timeline events yet',
          style: AppFonts.bodyMedium(color: _muted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          'DISPATCH TIMELINE',
          style: AppFonts.labelMedium(color: _muted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 16),
        ...detail.timeline.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == detail.timeline.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateTimeFormat.format(event.timestamp),
                          style: AppFonts.bodySmall(color: _muted).copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          event.subtitle,
                          style: AppFonts.bodyMedium(color: _muted).copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        if (event.trackingNumber != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tracking: ${event.trackingNumber}',
                            style: AppFonts.bodyMedium(color: _accent).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final showDispatchFooter = detail != null &&
        (_tabController.index == 0 || _tabController.index == 1);

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
          detail?.requestCode ?? 'Material Request',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              const Divider(height: 1, color: _divider),
              TabBar(
                controller: _tabController,
                onTap: (_) => setState(() {}),
                labelColor: AppColors.inkStrong,
                unselectedLabelColor: _muted,
                indicatorColor: AppColors.inkStrong,
                indicatorWeight: 2.5,
                labelStyle: AppFonts.bodyMedium(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: AppFonts.bodyMedium(color: _muted)
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Dispatch'),
                  Tab(text: 'Timeline'),
                ],
              ),
            ],
          ),
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
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _overviewTab(),
                    _dispatchTab(),
                    _timelineTab(),
                  ],
                ),
      bottomNavigationBar: showDispatchFooter
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _onDispatch,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkStrong,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create Dispatch',
                      style: AppFonts.titleMedium(color: AppColors.white)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
