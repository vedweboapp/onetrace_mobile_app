import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/application/employee_qr_scan_flow.dart';

class EmployeeQrScanPage extends ConsumerStatefulWidget {
  const EmployeeQrScanPage({super.key});

  static const path = '/employee-role/scan-qr';
  static const name = 'employee-scan-qr';

  @override
  ConsumerState<EmployeeQrScanPage> createState() => _EmployeeQrScanPageState();
}

class _EmployeeQrScanPageState extends ConsumerState<EmployeeQrScanPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_startScan);
  }

  Future<void> _startScan() async {
    await runEmployeeQrScanFlow(
      context,
      ProviderScope.containerOf(context),
    );
    if (mounted && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        title: Text(
          'Scan QR',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
