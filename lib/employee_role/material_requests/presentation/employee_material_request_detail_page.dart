import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_const_widget.dart';
import 'package:red5/employee_role/jobs/data/assigned_jobs_filter.dart';
import 'package:red5/employee_role/material_requests/presentation/employee_dispatch_detail_page.dart';
import 'package:red5/employee_role/material_requests/presentation/employee_return_request_detail_page.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';
import 'package:red5/features/material_requests/data/material_requests_api_client.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_request_widgets.dart';

/// Operative material-request detail: Overview · Dispatch · Return · Timesheet.
class EmployeeMaterialRequestDetailPage extends ConsumerStatefulWidget {
  const EmployeeMaterialRequestDetailPage({
    super.key,
    required this.materialRequestId,
  });

  static const pathPrefix = '/employee-role/material-requests';
  static const name = 'employee-material-request-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String materialRequestId;

  @override
  ConsumerState<EmployeeMaterialRequestDetailPage> createState() =>
      _EmployeeMaterialRequestDetailPageState();
}

class _EmployeeMaterialRequestDetailPageState
    extends ConsumerState<EmployeeMaterialRequestDetailPage>
    with SingleTickerProviderStateMixin {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _fieldBg = Color(0xFFF9FAFB);
  static const _darkblack = Colors.black;

  late final TabController _tabController;
  MaterialRequestRead? _request;
  List<MaterialDispatchRead> _dispatches = const [];
  List<MaterialReturnRequestRead> _returns = const [];
  final Map<int, TextEditingController> _receivedByControllers = {};
  var _loading = true;
  String? _errorMessage;

  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _receivedByControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _receivedByControllerFor(int dispatchId) {
    return _receivedByControllers.putIfAbsent(
      dispatchId,
      TextEditingController.new,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(materialRequestsApiClientProvider);
      final storage = sl<LocalStorage>();
      final workerId = int.tryParse(
        AssignedJobsFilter.currentWorkerId(storage) ?? '',
      );

      final request = await api.fetchMaterialRequestById(
        widget.materialRequestId.trim(),
      );

      // Dispatch uses worker + material_request (not job / job_worker).
      var dispatches = const <MaterialDispatchRead>[];
      var returns = const <MaterialReturnRequestRead>[];
      try {
        dispatches = await api.fetchDispatches(
          workerId: workerId,
          materialRequestId: request.id,
        );
      } catch (_) {
        dispatches = const [];
      }
      try {
        returns = await api.fetchReturnRequests(
          workerId: workerId,
          materialRequestId: request.id,
        );
      } catch (_) {
        // Fallback: some backends filter return-request by job instead.
        final returnsByJob = <MaterialReturnRequestRead>[];
        final seen = <int>{};
        for (final job in request.jobs) {
          try {
            final rows = await api.fetchReturnRequests(
              workerId: workerId,
              jobId: job.id,
            );
            for (final row in rows) {
              if (seen.add(row.id)) returnsByJob.add(row);
            }
          } catch (_) {}
        }
        returns = returnsByJob;
      }

      if (!mounted) return;
      setState(() {
        _request = request;
        _dispatches = dispatches;
        _returns = returns;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          error,
          genericFallback: 'Could not load material request.',
        );
      });
    }
  }

  Widget _card({
    required Widget child,
    Color? color,
    EdgeInsetsGeometry? padding,
    BorderRadius? radius,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: radius ?? BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _overviewTab(MaterialRequestRead request) {
    final detail = request.toDetail();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        vGap(10),
        Text(
          'BASIC INFO',
          style: AppFonts.labelMedium(color: _darkblack).copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.7,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _overviewInfoRow(
          'Status',
          detail.displayStatusLabel,
          isStatus: true,
          status: detail.status,
          statusBg: detail.statusBg,
          statusFg: detail.statusFg,
        ),
        const SizedBox(height: 24),
        Divider(color: Colors.grey),
        const SizedBox(height: 12),
        _card(
          padding: EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _card(
                // padding: EdgeInsets.all(16),
                radius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                color: Colors.grey[50],
                child: Text(
                  'JOBS',
                  style: AppFonts.labelMedium(color: _muted).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    fontSize: 16,
                  ),
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.jobs[i].jobCode,
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail.jobs[i].projectName,
                          style: AppFonts.bodyMedium(
                            color: _muted,
                          ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                      ],
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
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              if (detail.items.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      _itemsHeader(),
                      const SizedBox(height: 10),
                      Divider(thickness:1,color: Colors.grey),
                      for (final item in detail.items) _itemsRow(item),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overviewInfoRow(
    String label,
    String value, {
    bool isStatus = false,
    MaterialRequestStatus? status,
    Color? statusBg,
    Color? statusFg,
    bool multiline = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppFonts.labelMedium(color: _muted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        if (isStatus && status != null)
          MaterialRequestStatusBadge(
            status: status,
            label: value,
            background: statusBg,
            foreground: statusFg,
          )
        else
          Text(
            value.trim().isEmpty ? '—' : value,
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: multiline ? 14 : 15,
              height: multiline ? 1.4 : 1.2,
            ),
          ),
      ],
    );
  }

  Widget _itemsHeader() {
    final style = AppFonts.labelMedium(
      color: _muted,
    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5, fontSize: 10);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: 150, child: Text('ITEM NAME', style: style)),
            SizedBox(width: 100, child: Text('REQUESTED', style: style)),
            SizedBox(width: 100, child: Text('DISPATCHED', style: style)),
            SizedBox(width: 100, child: Text('PENDING', style: style)),
          ],
        ),
      ),
    );
  }

  Widget _itemsRow(MaterialRequestItemLine item) {
    final valueStyle = AppFonts.bodySmall(
      color: AppColors.inkStrong,
    ).copyWith(fontWeight: FontWeight.w600, fontSize: 12);
    final pendingStyle = item.highlightPending
        ? valueStyle.copyWith(color: const Color(0xFFDC2626))
        : valueStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: Text(item.itemName, style: valueStyle)),
            SizedBox(
              width: 100,
              child: Text(item.requestedLabel, style: valueStyle),
            ),
            SizedBox(
              width: 100,
              child: Text(item.dispatchedLabel, style: valueStyle),
            ),
            SizedBox(
              width: 100,
              child: Text(item.pendingLabel, style: pendingStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dispatchTab() {
    if (_dispatches.isEmpty) {
      return Center(
        child: Text(
          'No dispatches yet',
          style: AppFonts.bodyMedium(color: _muted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _dispatches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dispatch = _dispatches[index];
        final controller = _receivedByControllerFor(dispatch.id);
        if (controller.text.isEmpty &&
            (dispatch.receivedBy?.trim().isNotEmpty ?? false)) {
          controller.text = dispatch.receivedBy!.trim();
        }
        final firstItem = dispatch.items.isNotEmpty
            ? dispatch.items.first
            : null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.push(
                  EmployeeDispatchDetailPage.pathFor(dispatch.id.toString()),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dispatch.code,
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Received By',
                style: AppFonts.labelMedium(
                  color: _muted,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  filled: true,
                  fillColor: _fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Received Item',
                style: AppFonts.labelMedium(
                  color: _muted,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (firstItem == null)
                Text('No items', style: AppFonts.bodyMedium(color: _muted))
              else
                InkWell(
                  onTap: () => context.push(
                    EmployeeDispatchDetailPage.pathFor(dispatch.id.toString()),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          firstItem.itemName,
                          style: AppFonts.bodyMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        firstItem.quantityLabel,
                        style: AppFonts.bodyMedium(
                          color: _muted,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              if (dispatch.items.length > 1) ...[
                const SizedBox(height: 6),
                Text(
                  '+${dispatch.items.length - 1} more item(s)',
                  style: AppFonts.bodySmall(color: _muted),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _returnTab() {
    if (_returns.isEmpty) {
      return Center(
        child: Text(
          'No return requests yet',
          style: AppFonts.bodyMedium(color: _muted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _returns.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final row = _returns[index];
        final dateLabel = row.requestedDate == null
            ? '—'
            : _dateFormat.format(row.requestedDate!);
        return Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push(
              EmployeeReturnRequestDetailPage.pathFor(row.id.toString()),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.code,
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
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
                          (row.statusName ?? 'Return request').trim(),
                          style: AppFonts.labelMedium(
                            color: const Color(0xFFC2410C),
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${row.itemCount} items · Qty ${row.totalQuantity}',
                    style: AppFonts.bodyMedium(
                      color: _muted,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(dateLabel, style: AppFonts.bodySmall(color: _muted)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _timesheetTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Timesheet for this material request will appear here.',
          textAlign: TextAlign.center,
          style: AppFonts.bodyMedium(color: _muted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;

    return Scaffold(
      backgroundColor: Colors.white,
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
          request?.requestNumber ?? 'Material Request',
          style: AppFonts.titleMedium(
            fontSize: 16.0,
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800,),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              const Divider(height: 1, color: _divider),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.inkStrong,
                unselectedLabelColor: _muted,
                indicatorColor: AppColors.inkStrong,
                indicatorWeight: 2.5,
                labelStyle: AppFonts.bodyMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: AppFonts.bodyMedium(
                  color: _muted,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Dispatch'),
                  Tab(text: 'Return'),
                  Tab(text: 'Timesheet'),
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
          : request == null
          ? const SizedBox.shrink()
          : TabBarView(
              controller: _tabController,
              children: [
                _overviewTab(request),
                _dispatchTab(),
                _returnTab(),
                _timesheetTab(),
              ],
            ),
    );
  }
}
