import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/bill_models.dart';
import 'package:red5/features/dashboard/presentation/views/add_bill_page.dart';
import 'package:red5/features/dashboard/presentation/views/bill_preview_page.dart';

class BillDetailPage extends StatefulWidget {
  const BillDetailPage({super.key, required this.billId});

  static const pathPrefix = '/bills';
  static const name = 'bill-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String billId;

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage>
    with SingleTickerProviderStateMixin {
  static const _labelGrey = Color(0xFF9CA3AF);
  static const _divider = Color(0xFFE5E7EB);
  static const _searchBg = Color(0xFFF5F5F5);
  late final TabController _tabController;
  final _jobsSearchController = TextEditingController();
  late final BillDetail _detail;

  static final _displayDate = DateFormat('MMM d, yyyy');
  static final _jobRangeDate = DateFormat('MMM d');

  @override
  void initState() {
    super.initState();
    _detail = BillMockData.detailForId(widget.billId);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _jobsSearchController.addListener(() => setState(() {}));
  }

  String _formatDate(DateTime? value) =>
      value == null ? '—' : _displayDate.format(value);

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _jobsSearchController.dispose();
    super.dispose();
  }

  void _onEdit() => context.push(AddBillPage.path);

  void _onSend() {
    context.showAppTopToast(
      title: 'Bill order sent (preview)',
      type: AppTopToastType.success,
    );
  }

  void _onPreview() {
    context.push(BillPreviewPage.pathFor(widget.billId));
  }

  String _jobDateRange(BillJobLineItem item) {
    final start = item.startDate;
    final end = item.endDate;
    if (start == null && end == null) return '—';
    if (start != null && end != null) {
      return '${_jobRangeDate.format(start)} - ${_jobRangeDate.format(end)}';
    }
    if (start != null) return _jobRangeDate.format(start);
    return _jobRangeDate.format(end!);
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.labelSmall(color: AppColors.inkStrong).copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _subsectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        text,
        style: AppFonts.titleSmall(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.labelSmall(color: _labelGrey).copyWith(
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _value(String text, {bool semibold = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: semibold ? FontWeight.w600 : FontWeight.w500,
          fontSize: 15,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _twoColumnRow({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(leftLabel),
              _value(leftValue),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(rightLabel),
              _value(rightValue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusHeader(BillDetail detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail.billNumber,
              style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: detail.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            detail.statusLabel,
            style: AppFonts.titleMedium(color: detail.statusColor).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressBlock(BillAddress address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Address'),
        _value(address.street),
        _twoColumnRow(
          leftLabel: 'City',
          leftValue: address.city,
          rightLabel: 'State/Province',
          rightValue: address.state,
        ),
        _twoColumnRow(
          leftLabel: 'Postal Code',
          leftValue: address.postalCode,
          rightLabel: 'Country',
          rightValue: address.country,
        ),
      ],
    );
  }

  Widget _notesBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _overviewTab(BillDetail detail) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _sectionTitle('Bill Order Details'),
        _label('User Name'),
        _value(detail.userName),
        _label('Contact Person'),
        _value(detail.contactPerson),
        _label('Project Name'),
        _value(detail.projectName),
        _twoColumnRow(
          leftLabel: 'Issue Date',
          leftValue: _formatDate(detail.issueDate),
          rightLabel: 'Due Date',
          rightValue: _formatDate(detail.dueDate),
        ),
        _label('Payment Terms'),
        _value(detail.paymentTerms),
        _subsectionTitle('Billing Address'),
        _addressBlock(detail.billingAddress),
        _subsectionTitle('Shipping Address'),
        _addressBlock(detail.shippingAddress),
        _sectionTitle('Notes & Terms'),
        _notesBox(detail.notes.trim().isEmpty ? '—' : detail.notes),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _jobsSearchBar() {
    final hasQuery = _jobsSearchController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _jobsSearchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search Items...',
          hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
              .copyWith(fontSize: 15, fontWeight: FontWeight.w400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF9CA3AF),
            size: 22,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _jobsSearchController.clear(),
                  icon: const Icon(
                    Icons.cancel,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _jobListTile(BillJobLineItem item) {
    final statusLabel = billJobStatusLabel(item.status);
    final statusColor = billJobStatusColor(item.status);
    final dateRange = _jobDateRange(item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.showAppTopToast(
            title: 'Job detail coming soon',
            type: AppTopToastType.info,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _divider)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.jobName,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.location,
                      style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                        children: [
                          TextSpan(text: '$dateRange - '),
                          TextSpan(
                            text: statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<BillJobLineItem> _filteredJobs(BillDetail detail) {
    final query = _jobsSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return detail.jobItems;
    return detail.jobItems
        .where(
          (item) =>
              item.jobName.toLowerCase().contains(query) ||
              item.location.toLowerCase().contains(query) ||
              item.projectName.toLowerCase().contains(query) ||
              billJobStatusLabel(item.status).toLowerCase().contains(query),
        )
        .toList();
  }

  Widget _jobsTab(BillDetail detail) {
    final jobs = _filteredJobs(detail);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        Text(
          'Jobs',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 12),
        _jobsSearchBar(),
        const SizedBox(height: 8),
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No jobs match your search',
                style: AppFonts.bodyMedium(color: _labelGrey),
              ),
            ),
          )
        else
          for (final item in jobs) _jobListTile(item),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData? leadingIcon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18),
              const SizedBox(width: 10),
            ] else
              const SizedBox(width: 28),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.titleMedium(color: AppColors.white).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Bill Order Details',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: _onEdit,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.inkStrong,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.inkStrong,
                unselectedLabelColor: _labelGrey,
                indicatorColor: AppColors.inkStrong,
                indicatorWeight: 2.5,
                labelStyle: AppFonts.labelMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: AppFonts.labelMedium(
                  color: _labelGrey,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Jobs'),
                ],
              ),
              const Divider(height: 1, thickness: 1, color: _divider),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_tabController.index == 0) _statusHeader(detail),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _overviewTab(detail),
                _jobsTab(detail),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: _divider)),
            ),
            child: Column(
              children: [
                _actionButton(
                  label: 'Send Bill Order',
                  leadingIcon: Icons.send_outlined,
                  onPressed: _onSend,
                ),
                const SizedBox(height: 10),
                _actionButton(
                  label: 'Preview Bill Order',
                  leadingIcon: null,
                  onPressed: _onPreview,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
