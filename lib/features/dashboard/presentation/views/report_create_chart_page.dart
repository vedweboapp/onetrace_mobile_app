import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/data/report_chart_config.dart';
import 'package:red5/features/dashboard/data/report_models.dart';
import 'package:red5/features/dashboard/presentation/views/report_summary_page.dart';
import 'package:red5/features/dashboard/presentation/views/widgets/report_chart_preview.dart';

/// Chart builder screen opened from report summary (UI preview).
class ReportCreateChartPage extends StatefulWidget {
  const ReportCreateChartPage({
    super.key,
    required this.reportId,
    this.initialConfig,
  });

  static const pathSuffix = '/create-chart';
  static const name = 'report-create-chart';

  static String pathFor(String reportId) =>
      '${ReportSummaryPage.pathFor(reportId)}$pathSuffix';

  final String reportId;
  final ReportChartConfig? initialConfig;

  @override
  State<ReportCreateChartPage> createState() => _ReportCreateChartPageState();
}

class _ReportCreateChartPageState extends State<ReportCreateChartPage> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _fieldBg = Color(0xFFF9FAFB);
  static const _accent = Color(0xFF3B82F6);

  late ReportChartType _chartType;
  late String _measure;
  late String _grouping;
  late String _sortBy;
  late bool _shortenNumbers;

  late final TextEditingController _benchmarkController;
  late final TextEditingController _maxGroupingController;

  static const _measureOptions = [
    'Record Count',
    'Sum of Amount',
    'Average Progress',
  ];

  static const _groupingOptions = [
    'Lead Owner - Leads',
    'Status - Projects',
    'Client - Projects',
  ];

  static const _sortOptions = [
    'Label Ascending',
    'Label Descending',
    'Value Ascending',
    'Value Descending',
  ];

  late final List<ReportListCardItem> _cards;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _chartType = config?.chartType ?? ReportChartType.column;
    _measure = config?.measure ?? 'Record Count';
    _grouping = config?.grouping ?? 'Status - Projects';
    _sortBy = config?.sortBy ?? 'Label Ascending';
    _shortenNumbers = config?.shortenNumbers ?? true;
    _benchmarkController = TextEditingController(text: config?.benchmark ?? '');
    _maxGroupingController =
        TextEditingController(text: config?.maxGrouping ?? '75');
    _cards = ReportMockData.isNewReport(widget.reportId)
        ? ReportMockData.cardsForNewReport()
        : ReportMockData.listCardsFor(widget.reportId);
    _benchmarkController.addListener(() => setState(() {}));
    _maxGroupingController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _benchmarkController.dispose();
    _maxGroupingController.dispose();
    super.dispose();
  }

  ReportChartConfig get _currentConfig => ReportChartConfig(
        chartType: _chartType,
        measure: _measure,
        grouping: _grouping,
        sortBy: _sortBy,
        shortenNumbers: _shortenNumbers,
        benchmark: _benchmarkController.text.trim().isEmpty
            ? null
            : _benchmarkController.text.trim(),
        maxGrouping: _maxGroupingController.text.trim().isEmpty
            ? '75'
            : _maxGroupingController.text.trim(),
      );

  ReportChartSeries get _chartSeries => _currentConfig.seriesFor(_cards);

  void _onSave() {
    context.pop(_currentConfig);
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text,
        style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _configCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _accent),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppFonts.titleMedium(color: AppColors.inkStrong)
                    .copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppFonts.bodyMedium(color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: _fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent),
        ),
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppFonts.bodySmall(color: _muted).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: _accent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.inkStrong,
        ),
        title: Text(
          widget.initialConfig == null ? 'Create Chart' : 'Update Chart',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit is coming soon')),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 22),
            color: AppColors.inkStrong,
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                ReportChartPreview(
                  title: 'PREVIEW',
                  showColorLegend: false,
                  margin: EdgeInsets.zero,
                  series: _chartSeries,
                  chartType: _chartType,
                  onChartTypeChanged: (type) =>
                      setState(() => _chartType = type),
                ),
                _sectionTitle('Configuration'),
                _configCard(
                  icon: Icons.storage_rounded,
                  title: 'Data Source',
                  children: [
                    _fieldLabel('Measure (Y-axis)'),
                    _dropdownField(
                      value: _measure,
                      options: _measureOptions,
                      onChanged: (v) {
                        if (v != null) setState(() => _measure = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Grouping'),
                    _dropdownField(
                      value: _grouping,
                      options: _groupingOptions,
                      onChanged: (v) {
                        if (v != null) setState(() => _grouping = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _configCard(
                  icon: Icons.tune_rounded,
                  title: 'Display & Sorting',
                  children: [
                    _fieldLabel('Sort by'),
                    _dropdownField(
                      value: _sortBy,
                      options: _sortOptions,
                      onChanged: (v) {
                        if (v != null) setState(() => _sortBy = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Benchmark for Y-axis'),
                    _textField(
                      controller: _benchmarkController,
                      hint: 'Enter benchmark value',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _toggleRow(
                      title: 'Shorten numbers',
                      subtitle: 'e.g. 1.2M instead of 1,200,000',
                      value: _shortenNumbers,
                      onChanged: (v) => setState(() => _shortenNumbers = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _configCard(
                  icon: Icons.layers_outlined,
                  title: 'Grouping Limits',
                  children: [
                    _fieldLabel('Maximum Grouping'),
                    _textField(
                      controller: _maxGroupingController,
                      hint: '75',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Limits the total number of bars displayed on the chart.',
                      style: AppFonts.bodySmall(color: _muted).copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkStrong,
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _onSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF121212),
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Save Chart',
                          style: AppFonts.titleMedium(color: AppColors.white)
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
