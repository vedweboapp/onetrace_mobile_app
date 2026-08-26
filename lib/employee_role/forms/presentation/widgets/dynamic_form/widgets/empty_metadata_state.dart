part of '../dynamic_form.dart';

class _EmptyMetadataState extends StatelessWidget {
  const _EmptyMetadataState({required this.formName});

  final String formName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          formName,
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textFieldBorder,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.description_outlined, size: 40, color: AppColors.muted),
              const SizedBox(height: 8),
              Text(
                'No fields configured for this form. You can still add remarks and save.',
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
