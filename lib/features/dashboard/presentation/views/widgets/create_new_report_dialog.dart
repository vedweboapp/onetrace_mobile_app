import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Primary CRM modules available when creating a new report.
enum ReportPrimaryModule {
  leads,
  contacts,
  accounts,
  deals,
}

extension ReportPrimaryModuleX on ReportPrimaryModule {
  String get label => switch (this) {
        ReportPrimaryModule.leads => 'Leads',
        ReportPrimaryModule.contacts => 'Contacts',
        ReportPrimaryModule.accounts => 'Accounts',
        ReportPrimaryModule.deals => 'Deals',
      };
}

/// Shows the "Create New Report" module picker. Returns selected module on
/// Continue, or `null` when dismissed.
Future<ReportPrimaryModule?> showCreateNewReportDialog(
  BuildContext context,
) {
  return showDialog<ReportPrimaryModule>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => const CreateNewReportDialog(),
  );
}

class CreateNewReportDialog extends StatefulWidget {
  const CreateNewReportDialog({super.key});

  @override
  State<CreateNewReportDialog> createState() => _CreateNewReportDialogState();
}

class _CreateNewReportDialogState extends State<CreateNewReportDialog> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _muted = Color(0xFF6B7280);
  static const _tipBg = Color(0xFFEFF6FF);
  static const _tipBorder = Color(0xFFBFDBFE);
  static const _tipIcon = Color(0xFF3B82F6);

  ReportPrimaryModule? _selectedModule;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width;
    final dialogWidth = maxW > 520 ? 480.0 : maxW - 32;

    return Dialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create New Report',
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: AppColors.inkStrong,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Primary Module',
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Select the module that you would like to create a report '
                      'for. For example, if you want to see all Contacts and '
                      'the Deals added to them in the last month, select '
                      'Contacts as the primary module.',
                      style: AppFonts.bodyMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Primary Module',
                      style: AppFonts.bodyMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _moduleDropdown(),
                    const SizedBox(height: 16),
                    _tipBox(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: _divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _selectedModule == null
                          ? null
                          : () => Navigator.of(context).pop(_selectedModule),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF121212),
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: AppFonts.titleMedium(color: AppColors.white)
                            .copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ReportPrimaryModule?>(
          value: _selectedModule,
          isExpanded: true,
          hint: Text(
            '--Select Primary Module--',
            style: AppFonts.bodyMedium(color: const Color(0xFF9CA3AF)).copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280),
          ),
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          items: [
            for (final module in ReportPrimaryModule.values)
              DropdownMenuItem(
                value: module,
                child: Text(module.label),
              ),
          ],
          onChanged: (value) => setState(() => _selectedModule = value),
        ),
      ),
    );
  }

  Widget _tipBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _tipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tipBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: _tipIcon),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppFonts.bodySmall(color: const Color(0xFF1E40AF))
                    .copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: 'Tip: ',
                    style: AppFonts.bodySmall(color: const Color(0xFF1E40AF))
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(
                    text:
                        "Choose the module that contains the primary data you "
                        "want to analyze. You'll be able to add related modules "
                        'in the next step.',
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
