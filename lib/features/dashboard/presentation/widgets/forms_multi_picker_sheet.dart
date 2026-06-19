import 'package:flutter/material.dart';
import 'package:red5/core/models/named_id_option.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Multi-select bottom sheet for attaching forms to jobs or projects.
Future<List<NamedIdOption>?> showFormsMultiPickerSheet({
  required BuildContext context,
  required List<NamedIdOption> forms,
  required List<NamedIdOption> selected,
  String title = 'Select Forms',
  String description = 'Choose one or more forms.',
}) {
  return showModalBottomSheet<List<NamedIdOption>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      final selectedIds = selected.map((form) => form.id).toSet();
      final draft = <int>{...selectedIds};

      return StatefulBuilder(
        builder: (context, setModalState) {
          void toggle(NamedIdOption form) {
            setModalState(() {
              if (draft.contains(form.id)) {
                draft.remove(form.id);
              } else {
                draft.add(form.id);
              }
            });
          }

          final sorted = List<NamedIdOption>.from(forms)
            ..sort((a, b) => a.name.compareTo(b.name));

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
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: AppFonts.titleLarge(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: AppFonts.bodyMedium(color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  if (sorted.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No forms available.',
                        style: AppFonts.bodyMedium(color: AppColors.muted),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final form = sorted[index];
                          final isSelected = draft.contains(form.id);
                          return Material(
                            color: AppColors.transparent,
                            child: InkWell(
                              onTap: () => toggle(form),
                              borderRadius: BorderRadius.circular(14),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.surfaceHigh
                                      : AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.inkStrong
                                        : AppColors.borderLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        form.name,
                                        style: AppFonts.bodyMedium(
                                          color: AppColors.inkStrong,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Icon(
                                      isSelected
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      color: isSelected
                                          ? AppColors.inkStrong
                                          : AppColors.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final picked = forms
                          .where((form) => draft.contains(form.id))
                          .toList(growable: false);
                      Navigator.of(context).pop(picked);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkStrong,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      draft.isEmpty
                          ? 'Done'
                          : 'Done (${draft.length} selected)',
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
