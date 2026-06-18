import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

class EmployeeJobStatusCard extends StatelessWidget {
  const EmployeeJobStatusCard({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    final inProgress = normalized.contains('PROGRESS');
    final completed = normalized.contains('COMPLETE');
    final statusColor = inProgress
        ? const Color(0xFF5E4BFF)
        : completed
            ? const Color(0xFF00A553)
            : const Color(0xFFE34D1C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT STATUS',
            style: AppFonts.labelSmall(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: AppFonts.labelSmall(
              color: statusColor,
            ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

class EmployeeJobInfoSection extends StatelessWidget {
  const EmployeeJobInfoSection({super.key, required this.job});

  final EmployeeJobDetail job;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JOB DETAILS',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 16),
        _DetailPair(label: 'Project', value: job.project),
        _DetailPair(label: 'Client', value: job.client),
        _DetailPair(label: 'Site Contact', value: job.siteContact),
        _DetailPair(label: 'Block', value: job.block),
        _DetailPair(label: 'Plot', value: job.plot),
        const Divider(height: 30, color: AppColors.borderLight),
        Text(
          'Description',
          style: AppFonts.labelSmall(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          job.description,
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500, height: 1.22),
        ),
      ],
    );
  }
}

class _DetailPair extends StatelessWidget {
  const _DetailPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.labelSmall(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class EmployeeJobItemsCard extends StatelessWidget {
  const EmployeeJobItemsCard({super.key, required this.items});

  final List<EmployeeJobItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final item in items) ...[
                _JobItemRow(item: item),
                if (item != items.last) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _JobItemRow extends StatelessWidget {
  const _JobItemRow({required this.item});

  final EmployeeJobItem item;

  IconData get _icon {
    return switch (item.iconName) {
      'wire' => Icons.link_rounded,
      'sensor' => Icons.sensors_rounded,
      _ => Icons.inventory_2_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Icon(
            _icon,
            size: 16,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.name,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          item.quantityLabel,
          style: AppFonts.labelMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class EmployeeJobTabs extends StatelessWidget {
  const EmployeeJobTabs({
    super.key,
    required this.selectedTab,
    required this.onChanged,
  });

  final EmployeeJobDetailTab selectedTab;
  final ValueChanged<EmployeeJobDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Forms',
            selected: selectedTab == EmployeeJobDetailTab.forms,
            onTap: () => onChanged(EmployeeJobDetailTab.forms),
          ),
          _TabButton(
            label: 'Location',
            selected: selectedTab == EmployeeJobDetailTab.location,
            onTap: () => onChanged(EmployeeJobDetailTab.location),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.inkStrong : AppColors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: AppFonts.labelMedium(
              color: selected ? AppColors.inkStrong : AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class EmployeeJobPhotosPreview extends StatelessWidget {
  const EmployeeJobPhotosPreview({
    super.key,
    required this.beforeBytes,
    required this.afterBytes,
    required this.onEdit,
  });

  final Uint8List beforeBytes;
  final Uint8List afterBytes;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Job Photos',
                style: AppFonts.titleSmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: onEdit,
              child: Text(
                'Edit',
                style: AppFonts.labelLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _JobPhotoThumb(label: 'Before', bytes: beforeBytes),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _JobPhotoThumb(label: 'After', bytes: afterBytes),
            ),
          ],
        ),
      ],
    );
  }
}

class _JobPhotoThumb extends StatelessWidget {
  const _JobPhotoThumb({required this.label, required this.bytes});

  final String label;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.labelSmall(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}

class EmployeeBeforePhotoUpload extends StatelessWidget {
  const EmployeeBeforePhotoUpload({
    super.key,
    required this.photoBytes,
    required this.photoName,
    required this.isPicking,
    required this.onTap,
  });

  final Uint8List? photoBytes;
  final String? photoName;
  final bool isPicking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = photoBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Before Photo',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        DottedBorder(
          options: const RoundedRectDottedBorderOptions(
            color: AppColors.border,
            strokeWidth: 1,
            dashPattern: [5, 4],
            radius: Radius.circular(12),
            padding: EdgeInsets.zero,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isPicking ? null : onTap,
            child: SizedBox(
              width: double.infinity,
              height: 150,
              child: bytes == null
                  ? _BeforePhotoPlaceholder(isPicking: isPicking)
                  : _BeforePhotoPreview(
                      bytes: bytes,
                      fileName: photoName ?? 'before-photo.jpg',
                      isPicking: isPicking,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BeforePhotoPlaceholder extends StatelessWidget {
  const _BeforePhotoPlaceholder({required this.isPicking});

  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isPicking
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.muted,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to take photo',
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }
}

class _BeforePhotoPreview extends StatelessWidget {
  const _BeforePhotoPreview({
    required this.bytes,
    required this.fileName,
    required this.isPicking,
  });

  final Uint8List bytes;
  final String fileName;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(bytes, fit: BoxFit.cover),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPicking ? 'Opening...' : 'Retake',
                    style: AppFonts.labelSmall(
                      color: AppColors.white,
                    ).copyWith(fontWeight: FontWeight.w900),
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

class EmployeeSafetyChecklist extends StatelessWidget {
  const EmployeeSafetyChecklist({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<EmployeeSafetyChecklistItem> items;
  final void Function(String id, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety Checklist',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onChanged(item.id, !item.isChecked),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: item.isChecked,
                      onChanged: (value) => onChanged(item.id, value ?? false),
                      activeColor: AppColors.inkStrong,
                      side: const BorderSide(color: AppColors.border),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: AppFonts.bodySmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

List<EmployeeRequiredFormItem> buildEmployeeRequiredFormItems({
  required EmployeeJobDetail job,
  List<int> formIds = const [],
  Set<int> completedFormIds = const {},
  required bool hasQrScan,
  required bool dynamicFormComplete,
  bool isJobCompleted = false,
}) {
  final linkedFormIds = formIds.isNotEmpty ? formIds : job.linkedFormIds;
  final hasDynamicForms = linkedFormIds.isNotEmpty;

  final completedForms = linkedFormIds
      .where((formId) => completedFormIds.contains(formId))
      .length;
  final formItems = hasDynamicForms
      ? [
          EmployeeRequiredFormItem(
            id: 'linked_forms',
            title: isJobCompleted
                ? (linkedFormIds.length > 1
                    ? 'Submitted forms — tap to edit ($completedForms/${linkedFormIds.length})'
                    : 'Submitted form — tap to edit')
                : (linkedFormIds.length > 1
                    ? 'Fill required forms ($completedForms/${linkedFormIds.length})'
                    : 'Fill required form'),
            isComplete: dynamicFormComplete,
          ),
        ]
      : [
          EmployeeRequiredFormItem(
            id: 'safety_checklist',
            title: 'Fill safety checklist',
            isComplete: job.safetyChecklist.isNotEmpty &&
                job.safetyChecklist.every((item) => item.isChecked),
          ),
        ];

  return [
    ...formItems,
    EmployeeRequiredFormItem(
      id: 'qr_scan',
      title: 'Scan QR code',
      isComplete: hasQrScan,
      isOptional: true,
    ),
  ];
}

class EmployeeRequiredFormChecklist extends StatelessWidget {
  const EmployeeRequiredFormChecklist({
    super.key,
    required this.items,
    this.onItemTap,
  });

  final List<EmployeeRequiredFormItem> items;
  final void Function(String itemId)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final requiredItems =
        items.where((item) => !item.isOptional).toList(growable: false);
    final completed =
        requiredItems.where((item) => item.isComplete).length;
    final total = requiredItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Required Form',
                style: AppFonts.titleLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
            Text(
              '$completed/$total Complete',
              style: AppFonts.labelLarge(
                color: const Color(0xFF5E4BFF),
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < items.length; i++) ...[
          _RequiredFormTaskCard(
            item: items[i],
            onTap: onItemTap == null ? null : () => onItemTap!(items[i].id),
          ),
          if (i < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RequiredFormTaskCard extends StatelessWidget {
  const _RequiredFormTaskCard({required this.item, this.onTap});

  final EmployeeRequiredFormItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final complete = item.isComplete;
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: complete ? AppColors.inkStrong : AppColors.transparent,
              border: Border.all(
                color: complete ? AppColors.inkStrong : AppColors.border,
                width: 1.8,
              ),
            ),
            child: complete
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.white,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.title,
              style: AppFonts.bodyMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: complete
                  ? const Color(0xFFE9FFF5)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              complete
                  ? 'Complete'
                  : (item.isOptional ? 'Optional' : 'Pending'),
              style: AppFonts.labelSmall(
                color: complete
                    ? const Color(0xFF00A86B)
                    : AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

class EmployeeJobSignatureCapture extends StatelessWidget {
  const EmployeeJobSignatureCapture({
    super.key,
    required this.captured,
    required this.onCapture,
    required this.onClear,
  });

  final bool captured;
  final VoidCallback onCapture;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Site / Customer Signature',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        DottedBorder(
          options: const RoundedRectDottedBorderOptions(
            color: AppColors.border,
            strokeWidth: 1,
            dashPattern: [5, 4],
            radius: Radius.circular(12),
            padding: EdgeInsets.zero,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: captured ? onClear : onCapture,
            child: SizedBox(
              width: double.infinity,
              height: 120,
              child: captured
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.draw_rounded,
                            color: AppColors.inkStrong,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Signature captured · Tap to clear',
                            style: AppFonts.bodySmall(
                              color: AppColors.muted,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.gesture_rounded,
                            color: AppColors.muted,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add signature',
                            style: AppFonts.bodySmall(
                              color: AppColors.muted,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class EmployeeMaterialUsedField extends StatelessWidget {
  const EmployeeMaterialUsedField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material Used',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter material used',
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inkStrong),
            ),
          ),
        ),
      ],
    );
  }
}

class EmployeeJobLocationPanel extends StatelessWidget {
  const EmployeeJobLocationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 335,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -16,
            right: -16,
            top: 0,
            child: SizedBox(
              height: 230,
              child: Stack(
                fit: StackFit.expand,
                children: const [
                  CustomPaint(painter: _EmployeeLocationMapPainter()),
                  Center(child: _EmployeeLocationMapPin()),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 205,
            child: _EmployeeLocationCard(
              onDirections: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening directions')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeLocationMapPin extends StatelessWidget {
  const _EmployeeLocationMapPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.inkStrong,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on_rounded,
        color: AppColors.white,
        size: 25,
      ),
    );
  }
}

class _EmployeeLocationCard extends StatelessWidget {
  const _EmployeeLocationCard({required this.onDirections});

  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.inkStrong,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skyline Apartment Complex',
                      style: AppFonts.titleSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '742 Everglade Avenue, North\nDistrict, Unit 702, Block B',
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600, height: 1.28),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onDirections,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkStrong,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.near_me_rounded, size: 17),
                    label: Text(
                      'Get Directions',
                      style: AppFonts.titleSmall(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Icon(
                  Icons.copy_rounded,
                  color: AppColors.muted,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeLocationMapPainter extends CustomPainter {
  const _EmployeeLocationMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFDADADA);
    canvas.drawRect(Offset.zero & size, background);

    final center = Offset(size.width * 0.5, size.height * 0.48);
    final maxRadius = math.min(size.width, size.height) * 0.72;

    final district = Paint()
      ..color = const Color(0xFFE7E7E7)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 1.02,
        height: size.height * 0.86,
      ),
      district,
    );

    final roadPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var ring = 1; ring <= 8; ring++) {
      roadPaint.strokeWidth = ring == 3 || ring == 6 ? 2.4 : 1.2;
      final radius = maxRadius * (ring / 8);
      canvas.drawCircle(center, radius, roadPaint);
    }

    for (var i = 0; i < 38; i++) {
      final angle = (math.pi * 2 / 38) * i;
      final start = i.isEven ? maxRadius * 0.08 : maxRadius * 0.18;
      final end = maxRadius * (0.72 + (i % 5) * 0.045);
      roadPaint.strokeWidth = i % 7 == 0 ? 2.4 : 1.2;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * start,
        center + Offset(math.cos(angle), math.sin(angle)) * end,
        roadPaint,
      );
    }

    final blockPaint = Paint()..color = const Color(0xFFC2C2C2);
    for (var i = 0; i < 140; i++) {
      final ring = 2 + (i % 6);
      final angle = (math.pi * 2 / 24) * (i % 24) + ring * 0.09;
      final radius = maxRadius * (ring / 8) + (i % 3) * 5;
      final origin = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angle + math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 15 + (i % 4) * 5,
            height: 7 + (i % 3) * 4,
          ),
          const Radius.circular(1.5),
        ),
        blockPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
