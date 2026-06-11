import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/data/report_column_fields.dart';
import 'package:red5/features/dashboard/data/report_configure_state.dart';
import 'package:red5/features/dashboard/presentation/views/report_select_columns_page.dart';
import 'package:red5/features/dashboard/presentation/views/report_summary_page.dart';
import 'package:red5/features/dashboard/presentation/views/widgets/create_new_report_dialog.dart';

class ReportConfigureRouteExtra {
  const ReportConfigureRouteExtra({
    required this.primaryModule,
    this.initialState,
    this.replaceOnGenerate = true,
  });

  final ReportPrimaryModule primaryModule;
  final ReportConfigureState? initialState;

  /// When `false`, **Generate Report** pops back with the updated config
  /// (used when opening configure from an existing summary).
  final bool replaceOnGenerate;
}

/// Configure visible columns and grouping before generating a report.
class ReportConfigurePage extends StatefulWidget {
  const ReportConfigurePage({
    super.key,
    required this.reportId,
    required this.primaryModule,
    this.initialState,
    this.replaceOnGenerate = true,
  });

  static const pathSuffix = '/configure';
  static const name = 'report-configure';

  static String pathFor(String reportId) =>
      '${ReportSummaryPage.pathFor(reportId)}$pathSuffix';

  final String reportId;
  final ReportPrimaryModule primaryModule;
  final ReportConfigureState? initialState;
  final bool replaceOnGenerate;

  @override
  State<ReportConfigurePage> createState() => _ReportConfigurePageState();
}

class _ReportConfigurePageState extends State<ReportConfigurePage> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFF2563EB);
  static const _iconBg = Color(0xFFEFF6FF);

  late ReportConfigureState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState ?? ReportConfigureState.initial();
  }

  void _reset() => setState(() => _state = ReportConfigureState.initial());

  Future<void> _editVisibleColumns() async {
    final result = await showReportSelectColumnsPage(
      context,
      initialSelectedKeys: _state.visibleColumnKeys,
    );
    if (!mounted || result == null) return;
    setState(() => _state = _state.copyWith(visibleColumnKeys: result));
  }

  void _onPlaceholderEdit(String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$section configuration is coming soon')),
    );
  }

  void _onGenerateReport() {
    if (!widget.replaceOnGenerate) {
      context.pop(_state);
      return;
    }

    context.pushReplacement(
      ReportSummaryPage.pathFor(widget.reportId),
      extra: ReportSummaryRouteExtra(
        primaryModule: widget.primaryModule,
        columnKeys: _state.visibleColumnKeys,
      ),
    );
  }

  void _onReorderVisibleColumns(int oldIndex, int newIndex) {
    setState(() {
      final keys = List<String>.of(_state.visibleColumnKeys);
      if (newIndex > oldIndex) newIndex -= 1;
      final key = keys.removeAt(oldIndex);
      keys.insert(newIndex, key);
      _state = _state.copyWith(visibleColumnKeys: keys);
    });
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
        title: Column(
          children: [
            Text(
              'Configure Report',
              style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            Text(
              'Customize your data view',
              style: AppFonts.bodySmall(color: _muted).copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text(
              'Reset',
              style: AppFonts.bodyMedium(color: _accent).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
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
                _visibleColumnsCard(),
                const SizedBox(height: 12),
                _emptySectionCard(
                  icon: Icons.layers_outlined,
                  title: 'Row Groups',
                  emptyTitle: 'No Group Selected',
                  emptySubtitle:
                      'Group your data by specific row attributes.',
                  onEdit: () => _onPlaceholderEdit('Row Groups'),
                ),
                const SizedBox(height: 12),
                _emptySectionCard(
                  icon: Icons.view_column_outlined,
                  title: 'Column Groups',
                  emptyTitle: 'No Group Selected',
                  emptySubtitle: null,
                  onEdit: () => _onPlaceholderEdit('Column Groups'),
                ),
                const SizedBox(height: 12),
                _emptySectionCard(
                  icon: Icons.calculate_outlined,
                  title: 'Aggregate Columns',
                  emptyTitle: 'No Column Selected',
                  emptySubtitle:
                      'Add totals, averages, or custom counts.',
                  onEdit: () => _onPlaceholderEdit('Aggregate Columns'),
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
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _state.visibleColumnKeys.isEmpty
                      ? null
                      : _onGenerateReport,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Generate Report',
                    style: AppFonts.titleMedium(color: AppColors.white).copyWith(
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

  Widget _sectionEditButton(VoidCallback onPressed) {
    return Material(
      color: _accent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.edit_outlined, size: 18, color: AppColors.white),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: _accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        _sectionEditButton(onEdit),
      ],
    );
  }

  Widget _visibleColumnsCard() {
    final fields = ReportColumnCatalog.resolveSelected(
      _state.visibleColumnKeys,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.table_chart_outlined,
            title: 'Visible Columns',
            onEdit: _editVisibleColumns,
          ),
          const SizedBox(height: 14),
          if (fields.isEmpty)
            Text(
              'No columns selected',
              style: AppFonts.bodyMedium(color: _muted),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _onReorderVisibleColumns,
              itemCount: fields.length,
              itemBuilder: (context, index) {
                final field = fields[index];
                return _visibleColumnRow(
                  key: ValueKey(field.key),
                  label: field.label,
                  index: index,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _visibleColumnRow({
    required Key key,
    required String label,
    required int index,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Icon(
                Icons.drag_handle_rounded,
                color: Color(0xFF9CA3AF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptySectionCard({
    required IconData icon,
    required String title,
    required String emptyTitle,
    required String? emptySubtitle,
    required VoidCallback onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon: icon, title: title, onEdit: onEdit),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(icon, size: 36, color: const Color(0xFFD1D5DB)),
                const SizedBox(height: 12),
                Text(
                  emptyTitle,
                  style: AppFonts.titleMedium(color: AppColors.inkStrong)
                      .copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (emptySubtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    emptySubtitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.bodyMedium(color: _muted).copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
