import 'package:flutter/material.dart';
import 'package:red5/core/models/named_id_option.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';

/// Assign-forms bottom sheet for a project (multi-select with chips + search).
Future<List<int>?> showAssignProjectFormsSheet({
  required BuildContext context,
  required List<NamedIdOption> catalogForms,
  required List<int> initiallySelectedTemplateIds,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      final draft = <int>{...initiallySelectedTemplateIds};
      final searchController = TextEditingController();
      var searchQuery = '';

      return StatefulBuilder(
        builder: (context, setModalState) {
          void refreshSearch(String value) {
            setModalState(() => searchQuery = value.trim().toLowerCase());
          }

          void toggle(int formId) {
            setModalState(() {
              if (draft.contains(formId)) {
                draft.remove(formId);
              } else {
                draft.add(formId);
              }
            });
          }

          final sorted = List<NamedIdOption>.from(catalogForms)
            ..sort((a, b) => a.name.compareTo(b.name));
          final visible = searchQuery.isEmpty
              ? sorted
              : sorted
                  .where((f) => f.name.toLowerCase().contains(searchQuery))
                  .toList(growable: false);
          final selectedForms = sorted
              .where((f) => draft.contains(f.id))
              .toList(growable: false);

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assign forms',
                              style: AppFonts.titleLarge(
                                color: AppColors.inkStrong,
                              ).copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Select the forms available for this project\'s type.',
                              style: AppFonts.bodyMedium(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.muted,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                  if (selectedForms.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final form in selectedForms)
                          InputChip(
                            label: Text(form.name),
                            onDeleted: () => toggle(form.id),
                            deleteIcon: const Icon(Icons.close_rounded, size: 16),
                            backgroundColor: const Color(0xFFF3F4F6),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: searchController,
                    hintText: 'Search forms...',
                    prefixIcon: Icons.search_rounded,
                    fillColor: const Color(0xFFF3F4F6),
                    borderRadius: 12,
                    onChanged: refreshSearch,
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No forms match your search.',
                        textAlign: TextAlign.center,
                        style: AppFonts.bodyMedium(color: AppColors.muted),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final form = visible[index];
                          final isSelected = draft.contains(form.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => toggle(form.id),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.inkStrong,
                            title: Text(
                              form.name,
                              style: AppFonts.bodyMedium(
                                color: AppColors.inkStrong,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(draft.toList()..sort()),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      draft.isEmpty
                          ? 'Assign forms'
                          : 'Assign ${draft.length} Form${draft.length == 1 ? '' : 's'}',
                      style: AppFonts.titleSmall(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
