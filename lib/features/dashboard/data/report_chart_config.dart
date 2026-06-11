import 'package:red5/features/dashboard/data/report_models.dart';
import 'package:red5/features/dashboard/presentation/views/widgets/report_chart_preview.dart';

/// Saved chart configuration returned from the create-chart screen.
final class ReportChartConfig {
  const ReportChartConfig({
    required this.chartType,
    required this.measure,
    required this.grouping,
    required this.sortBy,
    required this.shortenNumbers,
    this.benchmark,
    this.maxGrouping = '75',
  });

  final ReportChartType chartType;
  final String measure;
  final String grouping;
  final String sortBy;
  final bool shortenNumbers;
  final String? benchmark;
  final String maxGrouping;

  ReportChartSeries seriesFor(List<ReportListCardItem> cards) {
    final active =
        cards.where((c) => c.status == ReportSummaryLifecycleStatus.active);
    final inactive =
        cards.where((c) => c.status == ReportSummaryLifecycleStatus.inactive);

    return switch (grouping) {
      'Status - Projects' => ReportChartSeries(
          labels: const ['Active', 'Inactive'],
          values: [
            active.length.toDouble(),
            inactive.length.toDouble(),
          ],
        ),
      'Client - Projects' => ReportChartSeries(
          labels: const ['Assigned', 'Unassigned'],
          values: [
            cards.where((c) => c.assigneeName.isNotEmpty).length.toDouble(),
            cards.where((c) => c.assigneeName.isEmpty).length.toDouble(),
          ],
        ),
      _ => ReportChartSeries(
          labels: const ['Active', 'Inactive'],
          values: [
            active.length.toDouble(),
            inactive.length.toDouble(),
          ],
        ),
    };
  }

  ReportChartConfig copyWith({ReportChartType? chartType}) {
    return ReportChartConfig(
      chartType: chartType ?? this.chartType,
      measure: measure,
      grouping: grouping,
      sortBy: sortBy,
      shortenNumbers: shortenNumbers,
      benchmark: benchmark,
      maxGrouping: maxGrouping,
    );
  }
}
