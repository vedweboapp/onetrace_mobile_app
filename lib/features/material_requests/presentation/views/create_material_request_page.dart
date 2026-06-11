import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_request_widgets.dart';

class _JobDraft {
  _JobDraft({required this.jobCode, required this.projectName});

  final String jobCode;
  final String projectName;
}

class _ItemDraft {
  _ItemDraft({
    required this.itemName,
    required this.quantity,
    required this.jobName,
  });

  final String itemName;
  final String quantity;
  final String jobName;
}

/// Create material request form (UI preview until API is available).
class CreateMaterialRequestPage extends StatefulWidget {
  const CreateMaterialRequestPage({super.key});

  static const pathPrefix = '/material-requests';
  static const name = 'create-material-request';
  static String get path => '$pathPrefix/add';

  @override
  State<CreateMaterialRequestPage> createState() =>
      _CreateMaterialRequestPageState();
}

class _CreateMaterialRequestPageState extends State<CreateMaterialRequestPage> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _fieldBg = Color(0xFFF9FAFB);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFF2563EB);

  String? _selectedJob;
  String? _selectedWorker;

  final List<_JobDraft> _jobs = [
    _JobDraft(
      jobCode: 'JOB-1024',
      projectName: 'Skyline Apartments Phase II',
    ),
  ];

  final List<_ItemDraft> _items = [
    _ItemDraft(
      itemName: 'Structural Steel Beams (HEB 200)',
      quantity: '12',
      jobName: 'Skyline Apartments Phase II',
    ),
  ];

  void _addJob() {
    setState(() {
      _jobs.add(
        _JobDraft(
          jobCode: 'JOB-${1040 + _jobs.length}',
          projectName: MaterialRequestMockData.jobOptions[
              _jobs.length % MaterialRequestMockData.jobOptions.length],
        ),
      );
    });
  }

  void _removeJob(int index) {
    if (_jobs.length <= 1) return;
    setState(() => _jobs.removeAt(index));
  }

  void _addItem() {
    setState(() {
      _items.add(
        _ItemDraft(
          itemName: MaterialRequestMockData.itemCatalog[
              _items.length % MaterialRequestMockData.itemCatalog.length],
          quantity: '1',
          jobName: _selectedJob ?? MaterialRequestMockData.jobOptions.first,
        ),
      );
    });
  }

  void _onCreate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Material request created')),
    );
    context.pop(true);
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              isExpanded: true,
              hint: Text(
                hint,
                style: AppFonts.bodyMedium(color: const Color(0xFF9CA3AF)),
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _jobCard(int index, _JobDraft job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JOB DETAILS',
                  style: AppFonts.labelMedium(color: _muted).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.jobCode,
                  style: AppFonts.titleMedium(color: AppColors.inkStrong)
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  'PROJECT NAME',
                  style: AppFonts.labelMedium(color: _muted).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.projectName,
                  style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeJob(index),
            icon: const Icon(Icons.delete_outline_rounded, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(_ItemDraft item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ITEM NAME',
            style: AppFonts.labelMedium(color: _muted).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.itemName,
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QTY',
                      style: AppFonts.labelMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.quantity,
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JOB NAME',
                      style: AppFonts.labelMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.jobName,
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.inkStrong,
        ),
        title: Text(
          'Create Request',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MaterialRequestSectionTitle('Basic Info'),
                      _dropdownField(
                        label: 'Job',
                        value: _selectedJob,
                        options: MaterialRequestMockData.jobOptions,
                        hint: 'e.g. Skyline Apartments Phase II',
                        onChanged: (v) => setState(() => _selectedJob = v),
                      ),
                      const SizedBox(height: 16),
                      _dropdownField(
                        label: 'Worker',
                        value: _selectedWorker,
                        options: MaterialRequestMockData.workerOptions,
                        hint: 'Select a Type',
                        onChanged: (v) => setState(() => _selectedWorker = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MaterialRequestSectionTitle('Request Jobs'),
                      for (var i = 0; i < _jobs.length; i++) _jobCard(i, _jobs[i]),
                      TextButton.icon(
                        onPressed: _addJob,
                        icon: const Icon(Icons.add, color: _accent, size: 20),
                        label: Text(
                          'Add Job',
                          style: AppFonts.bodyMedium(color: _accent).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MaterialRequestSectionTitle('Items'),
                      for (final item in _items) _itemCard(item),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, color: _accent, size: 20),
                        label: Text(
                          'Add Item',
                          style: AppFonts.bodyMedium(color: _accent).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  onPressed: _selectedWorker == null ? null : _onCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create',
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
}
