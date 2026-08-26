part of '../job_details.dart';

class _JobQrScannerPage extends StatefulWidget {
  const _JobQrScannerPage();

  @override
  State<_JobQrScannerPage> createState() => _JobQrScannerPageState();
}

class _JobQrScannerPageState extends State<_JobQrScannerPage> {
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
    String? value;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        value = code;
        break;
      }
    }
    if (value == null) return;
    _didReturn = true;
    Navigator.of(context).pop(value);
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
