import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/employee_earnings_repository.dart';
import '../enums/enums.dart';
import 'employee_earning_details_view.dart';

// ─────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────

extension EmployeeEarningsJobStatusX on JobStatus {
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
        return const Color(0xFFFFE39B);
      case JobStatus.approved:
        return const Color(0xFFFFE39B);
    }
  }

  Color get textColor {
    switch (this) {
      case JobStatus.paid:
        return const Color(0xFF1E9E5A);
      case JobStatus.inApproval:
        return const Color(0xFF8A6D00);
      case JobStatus.approved:
        return const Color(0xFF8A6D00);
    }
  }
}

class Job {
  final String id;
  final String jobName;
  final String projectName;
  final String clientName;
  final String siteAddress;
  final DateTime? date;
  final double amount;
  final JobStatus status;

  const Job({
    required this.id,
    required this.jobName,
    required this.projectName,
    required this.clientName,
    required this.siteAddress,
    required this.date,
    required this.amount,
    required this.status,
  });
}

// Simple filter enum for the tab row.

// ─────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────

final jobsProvider = FutureProvider<List<Job>>((ref) async {
  final response = await ref.watch(employeeEarningsProvider.future);
  return response.jobs
      .map(
        (earning) => Job(
          id: earning.id.toString(),
          jobName: earning.jobSerialNumber,
          projectName: earning.projectName,
          clientName: earning.clientName,
          siteAddress: earning.siteAddress,
          date: null,
          amount: earning.jobAmount,
          status: earning.status,
        ),
      )
      .toList(growable: false);
});

/// Currently selected filter chip.
final jobFilterProvider = StateProvider<JobFilter>((ref) => JobFilter.all);

/// Jobs after applying the selected filter.
final filteredJobsProvider = Provider<AsyncValue<List<Job>>>((ref) {
  final jobsAsync = ref.watch(jobsProvider);
  final filter = ref.watch(jobFilterProvider);

  return jobsAsync.whenData((jobs) {
    switch (filter) {
      case JobFilter.all:
        return jobs;
      case JobFilter.approved:
        return jobs.where((j) => j.status == JobStatus.approved).toList();
      case JobFilter.pending:
        return jobs.where((j) => j.status == JobStatus.inApproval).toList();
      case JobFilter.paid:
        return jobs.where((j) => j.status == JobStatus.paid).toList();
    }
  });
});

/// Summary totals shown in the dark card at the top.
class JobSummary {
  final double qualityApproved;
  final double pending;
  final double paid;

  const JobSummary({
    required this.qualityApproved,
    required this.pending,
    required this.paid,
  });
}

final jobSummaryProvider = Provider<AsyncValue<JobSummary>>((ref) {
  final earningsAsync = ref.watch(employeeEarningsProvider);
  return earningsAsync.whenData((response) {
    return JobSummary(
      qualityApproved: response.summary.totalEarning,
      pending: response.summary.unpaidAmount,
      paid: response.summary.paidAmount,
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────

class EmployeeEarningsPage extends ConsumerWidget {
  const EmployeeEarningsPage({super.key});

  static const path = '/employee-role/earnings';
  static const name = 'employee-earnings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const JobListScreen();
  }
}

class JobListScreen extends ConsumerWidget {
  const JobListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredJobs = ref.watch(filteredJobsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(elevation: 1, title: Text("Earnings")),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(employeeEarningsProvider);
            await ref.read(employeeEarningsProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              const SliverToBoxAdapter(child: _SummaryCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const SliverToBoxAdapter(child: _FilterRow()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              filteredJobs.when(
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No jobs found')),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _JobCard(job: jobs[index]),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, st) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Something went wrong: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SUMMARY CARD (dark card at top)
// ─────────────────────────────────────────────────────────────────────────

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(jobSummaryProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '€',
      decimalDigits: 0,
    );

    return summaryAsync.when(
      data: (summary) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1F),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _SummaryRow(
              dotColor: const Color(0xFFFF8A00),
              label: 'Total Earning',
              value: currency.format(summary.qualityApproved),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              dotColor: const Color(0xFFFFD400),
              label: 'Pending',
              value: currency.format(summary.pending),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              dotColor: const Color(0xFF2ECC71),
              label: 'Paid',
              value: currency.format(summary.paid),
            ),
          ],
        ),
      ),
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1F),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;

  const _SummaryRow({
    required this.dotColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// FILTER ROW (All / Approved / Pending / Paid)
// ─────────────────────────────────────────────────────────────────────────

class _FilterRow extends ConsumerWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(jobFilterProvider);

    Widget chip(JobFilter filter, String label) {
      final isSelected = selected == filter;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => ref.read(jobFilterProvider.notifier).state = filter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1B1B1F) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1B1B1F)
                    : const Color(0xFFE2E4E8),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          chip(JobFilter.all, 'All'),
          chip(JobFilter.approved, 'Approved'),
          chip(JobFilter.pending, 'Pending'),
          chip(JobFilter.paid, 'Paid'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// JOB CARD
// ─────────────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final Job job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '€',
      decimalDigits: 0,
    );
    final dateStr = job.date != null
        ? DateFormat('MMM dd, yyyy').format(job.date!)
        : 'Unknown date';

    return InkWell(
      onTap: () => context.push(EarningDetailsScreen.path, extra: job.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.jobName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.projectName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9AA0A6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currency.format(job.amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB4B8BE),
                  ),
                ),
                _StatusBadge(status: job.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final JobStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color bgColor;
    late final Color textColor;
    late final String label;

    switch (status) {
      case JobStatus.paid:
        bgColor = const Color(0xFFDFF6E8);
        textColor = const Color(0xFF1E9E5A);
        label = 'PAID';
        break;
      case JobStatus.inApproval:
      case JobStatus.approved:
        bgColor = const Color(0xFFFFE39B);
        textColor = const Color(0xFF8A6D00);
        label = status == JobStatus.inApproval ? 'PENDING' : 'APPROVED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
