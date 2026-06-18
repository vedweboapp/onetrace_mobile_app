import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

Future<NamedIdOption?> showProjectTypePickerSheet({
  required BuildContext context,
  required List<NamedIdOption> projectTypes,
  NamedIdOption? selected,
  required Future<NamedIdOption?> Function() onAddProjectType,
}) {
  return showModalBottomSheet<NamedIdOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                'Select Project Type',
                style: AppFonts.titleLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a type or create a new one.',
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              if (projectTypes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No project types yet.',
                    style: AppFonts.bodyMedium(color: AppColors.muted),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: projectTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final type = projectTypes[index];
                      final isSelected = selected?.id == type.id;
                      return Material(
                        color: AppColors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(type),
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 15,
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
                                    type.name,
                                    style: AppFonts.bodyMedium(
                                      color: AppColors.inkStrong,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    color: AppColors.inkStrong,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  final created = await onAddProjectType();
                  if (!context.mounted || created == null) return;
                  Navigator.of(context).pop(created);
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Add a project type',
                  style: AppFonts.bodyMedium(
                    color: const Color(0xFF2563EB),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
