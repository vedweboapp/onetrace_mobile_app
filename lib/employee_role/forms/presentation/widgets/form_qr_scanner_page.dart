import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/qr_code_utils.dart';

/// Full-screen QR scanner; returns the scanned string or `null` if cancelled.
Future<String?> openFormQrScanner(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const FormQrScannerPage()),
  );
}

class FormQrScannerPage extends StatefulWidget {
  const FormQrScannerPage({super.key});

  @override
  State<FormQrScannerPage> createState() => _FormQrScannerPageState();
}

class _FormQrScannerPageState extends State<FormQrScannerPage> {
  late final MobileScannerController _controller;
  bool _didReturn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didReturn) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        raw = code;
        break;
      }
    }
    if (raw == null) return;

    final qrCode = QrCodeUtils.normalizeScannedValue(raw);
    if (qrCode.isEmpty) return;

    _didReturn = true;
    Navigator.of(context).pop(qrCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
        title: Text(
          'Scan QR Code',
          style: AppFonts.titleLarge(
            color: AppColors.white,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.white, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40 + MediaQuery.paddingOf(context).bottom,
            child: Text(
              'Place the QR code inside the frame',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: AppColors.white,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
