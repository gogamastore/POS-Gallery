import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai Barcode')),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          if (_isProcessing) return; // Mencegah deteksi ganda

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? scannedValue = barcodes.first.rawValue;
            if (scannedValue != null && scannedValue.isNotEmpty) {
              setState(() {
                _isProcessing = true;
              });
              // Kembali ke layar sebelumnya dengan hasil pindaian
              // Pastikan konteks masih valid sebelum memanggil pop
              if (mounted) {
                 Navigator.of(context).pop(scannedValue);
              }
            }
          }
        },
      ),
    );
  }
}
