import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/employee_earnings_models.dart';
import '../data/employee_earnings_repository.dart';
import '../enums/enums.dart';

// ─────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────

class EarningDetail {
  final String jobName;
  final String projectName;
  final String clientName;
  final double hoursWorked;
  final double? hourlyRate;
  final double fixedRate;
  final double totalEarning;
  final DateTime? paymentDate;
  final double amountPaid;
  final String paymentMethod;
  final String transactionId;
  final String pinId;
  final String siteAddress;
  final DateTime? approvedOn;
  final JobStatus status;
  final String paymentStatusLabel;
  final DateTime? paymentDateSummary;

  const EarningDetail({
    required this.jobName,
    required this.projectName,
    required this.clientName,
    required this.hoursWorked,
    required this.hourlyRate,
    required this.fixedRate,
    required this.totalEarning,
    required this.paymentDate,
    required this.amountPaid,
    required this.paymentMethod,
    required this.transactionId,
    required this.pinId,
    required this.siteAddress,
    required this.approvedOn,
    required this.status,
    required this.paymentStatusLabel,
    required this.paymentDateSummary,
  });

  factory EarningDetail.fromJob(EmployeeEarningJob job) {
    return EarningDetail(
      jobName: job.jobName,
      projectName: job.projectName,
      clientName: job.clientName,
      hoursWorked: job.hoursWorked,
      hourlyRate: job.hourlyRate,
      fixedRate: job.fixedRate ?? 0,
      totalEarning: job.jobAmount,
      paymentDate: job.paymentDetails.paymentDate,
      amountPaid: job.paymentDetails.amountPaid,
      paymentMethod: job.paymentDetails.paymentMethod.isNotEmpty
          ? job.paymentDetails.paymentMethod
          : 'N/A',
      transactionId: job.paymentDetails.transactionId.isNotEmpty
          ? job.paymentDetails.transactionId
          : 'N/A',
      pinId: job.pinIds.isNotEmpty ? job.pinIds.join(', ') : 'N/A',
      siteAddress: job.siteAddress.isNotEmpty ? job.siteAddress : 'N/A',
      approvedOn: job.paymentSummary.approvedOn,
      status: job.status,
      paymentStatusLabel: job.paymentSummary.paymentStatus.isNotEmpty
          ? job.paymentSummary.paymentStatus.toUpperCase()
          : job.earningStatus.toUpperCase(),
      paymentDateSummary: job.paymentSummary.paymentDate,
    );
  }

  double get amount => amountPaid;
  JobStatus get paymentStatus => status;
  DateTime? get paidOnDate => paymentDateSummary;
}

extension EmployeeEarningDetailsJobStatusX on JobStatus {
  String get label {
    switch (this) {
      case JobStatus.paid:
        return 'PAID';
      case JobStatus.inApproval:
        return 'PENDING';
      case JobStatus.approved:
        return 'APPROVED';
    }
  }

  Color get bgColor {
    switch (this) {
      case JobStatus.paid:
        return const Color(0xFFDFF6E8);
      case JobStatus.inApproval:
      case JobStatus.approved:
        return const Color(0xFFFFE39B);
    }
  }

  Color get textColor {
    switch (this) {
      case JobStatus.paid:
        return const Color(0xFF1E9E5A);
      case JobStatus.inApproval:
      case JobStatus.approved:
        return const Color(0xFF8A6D00);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────

/// Fetch a single earning's detail by its job/earning id.

final earningDetailProvider = FutureProvider.family<EarningDetail, String>((
  ref,
  jobId,
) async {
  final response = await ref.watch(employeeEarningsProvider.future);
  final job = response.jobs.firstWhere(
    (item) => item.id.toString() == jobId,
    orElse: () => throw StateError('Earning not found for jobId=$jobId'),
  );
  return EarningDetail.fromJob(job);
});

// ─────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────

class EarningDetailsScreen extends ConsumerWidget {
  static const path = '/employee-role/earnings/details';
  static const name = 'employee-earnings-details';

  final String jobId;
  const EarningDetailsScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(earningDetailProvider(jobId));
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '€',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B1B1F)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Earning Details',
          style: TextStyle(
            color: Color(0xFF1B1B1F),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: detailAsync.when(
        data: (detail) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(employeeEarningsProvider);
            await ref.read(employeeEarningsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _SectionHeader('Job Summary'),
              _FieldRow(label: 'JOB NAME', value: detail.jobName),
              _FieldRow(label: 'PROJECT NAME', value: detail.projectName),
              _FieldRow(label: 'CLIENT NAME', value: detail.clientName),
              _FieldRow(
                label: 'HOURS WORKED',
                value: '${detail.hoursWorked.toStringAsFixed(0)} hrs',
              ),
              _FieldRow(
                label: 'HOURLY RATE',
                value: detail.hourlyRate != null
                    ? '${currency.format(detail.hourlyRate!)}/hr'
                    : 'N/A',
              ),
              _FieldRow(
                label: 'TOTAL EARNING',
                value: currency.format(detail.totalEarning),
                bold: true,
                isLast: true,
              ),

              const SizedBox(height: 28),
              _SectionHeader('Payment Details'),
              _FieldRow(
                label: 'DATE',
                value: detail.paymentDate != null
                    ? dateFmt.format(detail.paymentDate!)
                    : 'N/A',
              ),
              _FieldRow(label: 'AMOUNT', value: currency.format(detail.amount)),
              _FieldRow(label: 'PAYMENT METHOD', value: detail.paymentMethod),
              _FieldRow(label: 'TRANSACTION ID', value: detail.transactionId),
              _FieldRow(label: 'PIN ID', value: detail.pinId, isLast: true),

              const SizedBox(height: 28),
              _SectionHeader('Site Details'),
              _FieldRow(
                label: 'SITE ADDRESS',
                value: detail.siteAddress,
                isLast: true,
              ),

              const SizedBox(height: 28),
              _SectionHeader('Payment Summary'),
              _FieldRow(
                label: 'APPROVED ON',
                value: detail.approvedOn != null
                    ? dateFmt.format(detail.approvedOn!)
                    : 'N/A',
              ),
              _FieldRow(
                label: 'PAYMENT STATUS',
                isLast: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _StatusBadge(status: detail.paymentStatus),
                ),
              ),
              _FieldRow(
                label: 'PAYMENT DATE',
                value: detail.paidOnDate != null
                    ? dateFmt.format(detail.paidOnDate!)
                    : 'N/A',
              ),
              _FieldRow(
                label: 'AMOUNT',
                value: currency.format(detail.amount),
                isLast: true,
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1B1B1F),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// FIELD ROW (label on top, value below, divider under)
// ─────────────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  final bool bold;
  final bool isLast;

  const _FieldRow({
    required this.label,
    this.value,
    this.child,
    this.bold = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFEFF0F2), width: 1),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB4B8BE),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          child ??
              Text(
                value ?? '',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF1B1B1F),
                ),
              ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final JobStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: status.textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
