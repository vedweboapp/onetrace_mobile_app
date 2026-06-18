import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';

/// Section card — keeps metadata grouping (e.g. Basic Information).
class FormSectionPanel extends StatelessWidget {
  const FormSectionPanel({
    super.key,
    required this.section,
    required this.fieldBuilder,
  });

  final FormMetadataSection section;
  final Widget Function(FormMetadataField field) fieldBuilder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(
                  bottom: BorderSide(color: AppColors.borderLight),
                ),
              ),
              child: Text(
                section.name,
                style: AppFonts.titleSmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: _FieldList(
                fields: section.fields,
                fieldBuilder: fieldBuilder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldList extends StatelessWidget {
  const _FieldList({
    required this.fields,
    required this.fieldBuilder,
  });

  final List<FormMetadataField> fields;
  final Widget Function(FormMetadataField field) fieldBuilder;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in fields) ...[
          fieldBuilder(field),
          if (field != fields.last) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

/// Label + input shell used for every form field.
class FormFieldShell extends StatelessWidget {
  const FormFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.helpText,
    this.hideLabel = false,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? helpText;
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hideLabel) ...[
          Text.rich(
            TextSpan(
              text: label,
              style: AppFonts.titleSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
              children: required
                  ? [
                      TextSpan(
                        text: ' *',
                        style: AppFonts.titleSmall(
                          color: AppColors.accentRed,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: 8),
        ],
        child,
        if (helpText != null && helpText!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helpText!.trim(),
            style: AppFonts.bodySmall(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

/// Read-only metadata preview card (admin settings).
class FormMetadataPreviewTile extends StatelessWidget {
  const FormMetadataPreviewTile({
    super.key,
    required this.field,
  });

  final FormMetadataField field;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            field.fieldType,
            style: AppFonts.labelSmall(color: AppColors.mutedLight),
          ),
        ],
      ),
    );
  }
}
