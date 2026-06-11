import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dispatch/presentation/views/create_dispatch_page.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_request_widgets.dart';

/// Material request detail with Overview, Dispatch, and Timeline tabs.
class MaterialRequestDetailPage extends StatefulWidget {
  const MaterialRequestDetailPage({super.key, required this.materialRequestId});

  static const pathPrefix = '/material-requests';
  static const name = 'material-request-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String materialRequestId;

  @override
  State<MaterialRequestDetailPage> createState() =>
      _MaterialRequestDetailPageState();
}

class _MaterialRequestDetailPageState extends State<MaterialRequestDetailPage>
    with SingleTickerProviderStateMixin {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFF2563EB);

  late final TabController _tabController;
  late final MaterialRequestDetail _detail;

  static final _dateTimeFormat = DateFormat('MMM d, yyyy • hh:mm a');

  @override
  void initState() {
    super.initState();
    _detail = MaterialRequestMockData.detailForId(widget.materialRequestId);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onDispatch() async {
    final created = await context.push<bool?>(
      CreateDispatchPage.path,
      extra: CreateDispatchRouteExtra(
        materialRequestId: _detail.requestCode,
        dispatchTo: _detail.jobs.isNotEmpty
            ? _detail.jobs.first.projectName
            : null,
      ),
    );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispatch created')),
    );
  }

  Widget _infoTile(String label, String value) {
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
          if (label.toUpperCase() == 'STATUS')
            MaterialRequestStatusBadge(status: _detail.status)
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _card(
          child: Row(
            children: [
              _infoTile('Worker', _detail.workerName),
              _infoTile('Status', _detail.status.label),
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
              for (var i = 0; i < _detail.jobs.length; i++) ...[
                if (i > 0) const Divider(height: 20, color: _divider),
                Text(
                  _detail.jobs[i].jobCode,
                  style: AppFonts.titleMedium(color: AppColors.inkStrong)
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _detail.jobs[i].projectName,
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
              _itemsTableHeader(),
              const Divider(height: 1, color: _divider),
              for (final item in _detail.items) _itemsTableRow(item),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        for (final item in _detail.dispatchItems)
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
        ..._detail.timeline.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == _detail.timeline.length - 1;
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
    final showDispatchFooter =
        _tabController.index == 0 || _tabController.index == 1;

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
          _detail.requestCode,
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
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _overviewTab(),
                _dispatchTab(),
                _timelineTab(),
              ],
            ),
          ),
          if (showDispatchFooter)
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
                      style: AppFonts.titleMedium(color: AppColors.white)
                          .copyWith(
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
