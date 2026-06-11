import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/data/report_column_fields.dart';

/// Full-screen column picker matching the Select Columns mockup.
class ReportSelectColumnsPage extends StatefulWidget {
  const ReportSelectColumnsPage({
    super.key,
    required this.initialSelectedKeys,
  });

  final List<String> initialSelectedKeys;

  @override
  State<ReportSelectColumnsPage> createState() =>
      _ReportSelectColumnsPageState();
}

Future<List<String>?> showReportSelectColumnsPage(
  BuildContext context, {
  required List<String> initialSelectedKeys,
}) {
  return Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ReportSelectColumnsPage(
        initialSelectedKeys: initialSelectedKeys,
      ),
    ),
  );
}

class _ReportSelectColumnsPageState extends State<ReportSelectColumnsPage> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFF2563EB);
  static const _searchBg = Color(0xFFF5F5F5);

  final _searchController = TextEditingController();
  late List<String> _selectedKeys;
  ReportFieldType _typeFilter = ReportFieldType.all;

  @override
  void initState() {
    super.initState();
    _selectedKeys = List.of(widget.initialSelectedKeys);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReportFieldDefinition> get _allFields => ReportColumnCatalog.fields;

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  bool _matchesFilters(ReportFieldDefinition field) {
    if (_typeFilter != ReportFieldType.all && field.type != _typeFilter) {
      return false;
    }
    if (_searchQuery.isEmpty) return true;
    return field.label.toLowerCase().contains(_searchQuery);
  }

  List<ReportFieldDefinition> get _selectedFields {
    return [
      for (final key in _selectedKeys)
        if (ReportColumnCatalog.fieldByKey(key) != null)
          ReportColumnCatalog.fieldByKey(key)!,
    ];
  }

  List<ReportFieldDefinition> get _unselectedFields {
    final selected = _selectedKeys.toSet();
    return [
      for (final field in _allFields)
        if (!selected.contains(field.key) && _matchesFilters(field)) field,
    ];
  }

  bool get _allFilteredSelected {
    final visible = [
      for (final field in _allFields) if (_matchesFilters(field)) field,
    ];
    if (visible.isEmpty) return false;
    return visible.every((f) => _selectedKeys.contains(f.key));
  }

  void _toggleField(String key, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedKeys.contains(key)) _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }
    });
  }

  void _toggleSelectAll(bool? value) {
    if (value == true) {
      setState(() {
        for (final field in _allFields) {
          if (_matchesFilters(field) && !_selectedKeys.contains(field.key)) {
            _selectedKeys.add(field.key);
          }
        }
      });
      return;
    }
    setState(() {
      for (final field in _allFields) {
        if (_matchesFilters(field)) {
          _selectedKeys.remove(field.key);
        }
      }
    });
  }

  void _clearAll() => setState(() => _selectedKeys.clear());

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final key = _selectedKeys.removeAt(oldIndex);
      _selectedKeys.insert(newIndex, key);
    });
  }

  void _apply() => Navigator.of(context).pop(List.of(_selectedKeys));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const Divider(height: 1, color: _divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _searchAndFilterRow(),
            ),
            _selectAllRow(),
            const Divider(height: 1, color: _divider),
            Expanded(child: _columnsList()),
            const Divider(height: 1, color: _divider),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.inkStrong,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Columns',
                  style: AppFonts.titleMedium(color: AppColors.inkStrong)
                      .copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ReportColumnCatalog.totalCount} total fields available',
                  style: AppFonts.bodyMedium(color: _muted).copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _selectedKeys.isEmpty ? null : _clearAll,
            child: Text(
              'Clear all',
              style: AppFonts.bodyMedium(color: _accent).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilterRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _searchBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: _searchController,
              style: AppFonts.bodyMedium(color: AppColors.inkStrong),
              decoration: InputDecoration(
                hintText: 'Search columns...',
                hintStyle: AppFonts.bodyMedium(color: const Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _typeFilterDropdown(),
      ],
    );
  }

  Widget _typeFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ReportFieldType>(
          value: _typeFilter,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: [
            for (final type in ReportFieldTypeX.filterOptions)
              DropdownMenuItem(
                value: type,
                child: Text(type.label),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _typeFilter = value);
          },
        ),
      ),
    );
  }

  Widget _selectAllRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: _allFilteredSelected,
            tristate: true,
            activeColor: _accent,
            onChanged: _toggleSelectAll,
          ),
          Text(
            'Select All',
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '${_selectedKeys.length} selected',
              style: AppFonts.bodyMedium(color: _muted).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnsList() {
    final selected = _selectedFields;
    final unselected = _unselectedFields;

    if (selected.isEmpty && unselected.isEmpty) {
      return Center(
        child: Text(
          'No columns match your search',
          style: AppFonts.bodyMedium(color: _muted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      children: [
        if (selected.isNotEmpty) ...[
          _sectionHeader('COLUMNS'),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: _onReorder,
            itemCount: selected.length,
            itemBuilder: (context, index) {
              final field = selected[index];
              return _selectedRow(
                key: ValueKey(field.key),
                field: field,
                index: index,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        for (final field in unselected) _unselectedRow(field),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          Text(
            title,
            style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF)).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }

  Widget _selectedRow({
    required Key key,
    required ReportFieldDefinition field,
    required int index,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: true,
              activeColor: _accent,
              onChanged: (_) => _toggleField(field.key, false),
            ),
            Expanded(
              child: Text(
                field.label,
                style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unselectedRow(ReportFieldDefinition field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: false,
            activeColor: _accent,
            onChanged: (_) => _toggleField(field.key, true),
          ),
          Expanded(
            child: Text(
              field.label,
              style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.inkStrong,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: AppFonts.titleMedium(color: AppColors.inkStrong)
                      .copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _selectedKeys.isEmpty ? null : _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF121212),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Apply Selection',
                  style: AppFonts.titleMedium(color: AppColors.white).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
