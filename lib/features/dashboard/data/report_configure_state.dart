import 'package:red5/features/dashboard/data/report_column_fields.dart';

/// Report layout configuration before generating the summary view.
final class ReportConfigureState {
  const ReportConfigureState({
    required this.visibleColumnKeys,
    this.rowGroupKeys = const [],
    this.columnGroupKeys = const [],
    this.aggregateColumnKeys = const [],
  });

  final List<String> visibleColumnKeys;
  final List<String> rowGroupKeys;
  final List<String> columnGroupKeys;
  final List<String> aggregateColumnKeys;

  static ReportConfigureState initial() => const ReportConfigureState(
        visibleColumnKeys: ReportColumnCatalog.defaultSelectedKeys,
      );

  List<String> labelsFor(List<String> keys) {
    return [
      for (final key in keys)
        if (ReportColumnCatalog.fieldByKey(key) != null)
          ReportColumnCatalog.fieldByKey(key)!.label,
    ];
  }

  ReportConfigureState copyWith({
    List<String>? visibleColumnKeys,
    List<String>? rowGroupKeys,
    List<String>? columnGroupKeys,
    List<String>? aggregateColumnKeys,
  }) {
    return ReportConfigureState(
      visibleColumnKeys: visibleColumnKeys ?? this.visibleColumnKeys,
      rowGroupKeys: rowGroupKeys ?? this.rowGroupKeys,
      columnGroupKeys: columnGroupKeys ?? this.columnGroupKeys,
      aggregateColumnKeys: aggregateColumnKeys ?? this.aggregateColumnKeys,
    );
  }
}
